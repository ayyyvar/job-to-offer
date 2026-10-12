import Core
import FoundationModels
@testable import JobScout
import Testing

@Suite struct ModelProbeTests {
    @Test(.tags(.onDevice)) func probeReportsAvailabilityContextSizeAndEnglish() {
        guard SystemLanguageModel.default.isAvailable else {
            print("skip: on-device model unavailable: \(SystemLanguageModel.default.availability)")
            return
        }
        let capability = FoundationModelsClient().capability()
        #expect(capability.status == .available)
        #expect(capability.contextSize >= 4096)
        #expect(capability.supportedLanguages.contains("en"))
    }
}
