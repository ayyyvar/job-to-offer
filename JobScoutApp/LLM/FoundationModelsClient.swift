import Core
import FoundationModels

/// The only app file that imports FoundationModels (CLAUDE.md §4).
struct FoundationModelsClient: LLMClient {
    var model: SystemLanguageModel = .default

    var contextSize: Int { model.contextSize }

    func tokenCount(_ text: String) async throws -> Int { try await model.tokenCount(for: text) }

    func extract(postingText: String) async throws -> JobPosting {
        let instructions = try PromptRenderer.extract(postingText: "").instructions
        return try await generate(JobPosting.self, instructions: instructions, text: postingText) {
            try PromptRenderer.extract(postingText: $0).prompt
        }
    }

    func digest(postingText: String) async throws -> PostingDigest {
        let instructions = try PromptRenderer.digest(postingText: "").instructions
        return try await generate(PostingDigest.self, instructions: instructions, text: postingText) {
            try PromptRenderer.digest(postingText: $0).prompt
        }
    }

    func star(story: String) async throws -> StarStory {
        let instructions = try PromptRenderer.star(story: "").instructions
        return try await generate(StarStory.self, instructions: instructions, text: story) {
            try PromptRenderer.star(story: $0).prompt
        }
    }

    /// Loads the model before the user taps Parse (called when the detail screen opens).
    func prewarm() {
        guard model.isAvailable else { return }
        LanguageModelSession(model: model).prewarm()
    }

    /// Cuts `text` so instructions + schema + prompt leave `PromptBudget.outputReserve` tokens,
    /// then asks the model. On `contextSizeExceeded` it retries once with a 25 % tighter cut. On
    /// `unsupportedLanguageOrLocale` it retries once without the 1-3 word paragraphs: the language check
    /// rejected an English page on its header lines (threadly, docs/MODEL_BEHAVIOR.md §7.3). On
    /// `guardrailViolation` it retries once with visa/sponsor lines dropped and the short header paragraphs
    /// dropped: the safety filter can block on a sentence like "unable to sponsor work visas", and dropping
    /// visa lines alone did not clear it on one Holdout2 posting (docs/MODEL_BEHAVIOR.md). The caller still grounds against the original full
    /// text, so the eligibility gate still sees the dropped sentence.
    private func generate<T: Generable>(_ type: T.Type, instructions: String, text: String,
                                        prompt: (String) throws -> String) async throws -> T {
        do {
            return try await respond(type, instructions: instructions, text: text, prompt: prompt)
        } catch LLMError.failed(let reason) where reason == Self.unsupportedLanguage && Truncator.droppingShortParagraphs(text) != text {
            return try await respond(type, instructions: instructions, text: Truncator.droppingShortParagraphs(text), prompt: prompt)
        } catch LLMError.failed(let reason) where reason == Self.guardrailBlocked
            && Truncator.droppingShortParagraphs(Truncator.droppingVisaLines(text)) != text {
            let cut = Truncator.droppingShortParagraphs(Truncator.droppingVisaLines(text))
            return try await respond(type, instructions: instructions, text: cut, prompt: prompt)
        }
    }

    private func respond<T: Generable>(_ type: T.Type, instructions: String, text: String,
                                       prompt: (String) throws -> String) async throws -> T {
        if case .unavailable = model.availability { throw LLMError.failed(capability().statusText) }
        do {
            let overhead = try await model.tokenCount(for: Instructions(instructions))
                + model.tokenCount(for: T.generationSchema)
                + model.tokenCount(for: try prompt(""))
            var budget = PromptBudget.available(contextSize: contextSize, overheadTokens: overhead)
            for attempt in 1...2 {
                let cut = try await Truncator.truncate(text, toTokens: budget, count: tokenCount)
                let usedTokens = try await overhead + tokenCount(cut)
                await BudgetTelemetry.shared.record(promptTokens: usedTokens, contextSize: contextSize, truncated: cut != text)
                let session = LanguageModelSession(model: model, instructions: Instructions(instructions))
                do {
                    return try await session.respond(to: try prompt(cut), generating: T.self, options: Self.options).content
                } catch LanguageModelError.contextSizeExceeded where attempt == 1 {
                    budget = budget * 3 / 4
                }
            }
            throw LLMError.failed(Self.tooLong)
        } catch let error as LanguageModelError {
            throw LLMError.failed(Self.reason(error))
        }
    }

    /// Greedy: the same posting gives the same fields on every run (when the model scored, sampling gave
    /// 100/100/100/100 on one run and 80/75/70/70 on another for the same posting).
    static let options = GenerationOptions(samplingMode: .greedy, maximumResponseTokens: PromptBudget.outputReserve)

    static let tooLong = "The posting is too long for the on-device model, even after cutting it."
    static let unsupportedLanguage = "The on-device model does not support this posting's language. V1 reads English postings."
    static let guardrailBlocked = "The on-device safety filter blocked this posting. Paste the requirements as text and try again."

    static func reason(_ error: LanguageModelError) -> String {
        switch error {
        case .contextSizeExceeded: tooLong
        case .guardrailViolation: guardrailBlocked
        case .refusal: "The on-device model declined this posting."
        case .unsupportedLanguageOrLocale: unsupportedLanguage
        case .rateLimited: "The on-device model is busy. Try again in a moment."
        case .timeout: "The on-device model timed out. Try again."
        case .unsupportedCapability, .unsupportedTranscriptContent, .unsupportedGenerationGuide:
            "The on-device model cannot run this request: \(error.localizedDescription)"
        @unknown default: "On-device model error: \(error.localizedDescription)"
        }
    }

    /// Device and Siri language must be one the model supports.
    func supportsCurrentLocale() -> Bool { model.supportsLocale() }

    func capability() -> ModelCapability {
        ModelCapability(
            status: status(model.availability),
            contextSize: model.contextSize,
            supportedLanguages: model.supportedLanguages.map(\.minimalIdentifier).sorted()
        )
    }

    private func status(_ availability: SystemLanguageModel.Availability) -> ModelCapability.Status {
        switch availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .unavailable(reason: "This device does not support Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable(reason: "Apple Intelligence is off. Turn it on in Settings > Apple Intelligence & Siri.")
        case .unavailable(.modelNotReady):
            return .unavailable(reason: "The model is not ready yet (it may still be downloading). Try again later.")
        @unknown default:
            return .unavailable(reason: "Unknown reason: \(availability)")
        }
    }
}
