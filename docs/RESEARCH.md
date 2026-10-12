# External research for the on-device model (2026-09-28)

**TL;DR:** guided generation always runs the default guardrails, and the framework exposes no logprobs. freehire's MIT test tables show our eligibility rules get 74 of 102 labelled cases right; 7 regex changes reach 101/102. The Evaluations framework needs OS 27, so it cannot run on the macOS 26.6 host. Simulator results do not predict device results: iOS 27 ships a new model.

Labels: **VERIFIED** = a research agent fetched the page and saw the claim; **THIRD-PARTY** = someone else's report; **INFERENCE** = our reading. Recheck quotes before you cite them outside this repo. Local measurements are in `docs/MODEL_BEHAVIOR.md` §7–8.

---

## 1. Web (Apple documentation, WWDC, forums)

### 1.1 Field order and enum recall (`llmWork`)

- **VERIFIED:** "make sure the reasoning field is the first property". The same page warns that the model "may answer unreliably — occasionally answering correctly, and sometimes not". https://developer.apple.com/documentation/foundationmodels/prompting-an-on-device-foundation-model
- **VERIFIED:** properties "are generated in the order they are declared". https://developer.apple.com/videos/play/wwdc2025/301/
- **Local result:** moving all requirements before the enums (D2) lowered the holdout exact band from 14 to 9 (§7.3).
- **INFERENCE:** one short evidence field before `llmWork` (a quoted AI/LLM sentence or empty) is a smaller change. Swift can check the quote against the text, as `Grounding` does. Result: §3 below.

### 1.2 Language check (`unsupportedLanguageOrLocale`)

- **VERIFIED:** the framework "checks the language or languages of the input prompt text". Apple does not document how (classifier, segment size). https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models
- **VERIFIED:** `supportsLocale(_:)` checks the device locale, so it cannot prevent a false positive caused by the text.
- **THIRD-PARTY:** "an English label right before a French transcript makes Apple FM refuse with `unsupportedLanguageOrLocale`". https://github.com/getdictus/dictus-ios/issues/585
- **Local result:** merging the short paragraph into the next line did not help; dropping 1–3 word paragraphs did. The client retries that way.

### 1.3 Simulator vs device

- **Not found:** the string "unknown special token: com.apple.fm.language.safety_guardrail" in forums, docs or release notes (iOS 27 release notes checked).
- **THIRD-PARTY, the reverse mismatch:** "Neither 26.x simulator can generate on a macOS 27 host, because the safety classifier fails to load." https://github.com/taaltreelabs/on-device-llm/pull/9
- **VERIFIED:** iOS 27 ships a new on-device model ("AFM 3 Core", preferred on 45.6 % of prompts against 23.3 % for the 2025 baseline). https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models
- **VERIFIED:** WWDC26 241 prints `contextSize` 8192. No source explains the 4096 measured on the iPhone 16e. https://developer.apple.com/videos/play/wwdc2026/241/
- **INFERENCE:** the iOS 27 simulator runs the macOS 26 host model; its numbers are a proxy. Run the eval on the phone before any release decision.

### 1.4 Guardrail false positives

- **VERIFIED:** `.permissiveContentTransformations` "only works for generating a string value. When you use guided generation, the framework runs the default guardrails". https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output
- **VERIFIED:** Apple's advice: "experiment with re-phrasing the prompt to determine which phrases are activating the guardrails".
- **VERIFIED:** WWDC26 241: iOS 26.4 changes "reduce the number of false positives", with "even more improvements in iOS 27".
- **VERIFIED, forums:** an Apple engineer: "We're actively working to improve the guardrails and reduce false positives"; asks for Feedback reports with the Siri locale. https://developer.apple.com/forums/thread/787736 , https://developer.apple.com/forums/thread/802921
- **Local cases:** "We are unable to sponsor work visas for this position." (host, gate injection); variantly (simulator only).

### 1.5 Evaluations framework (WWDC26 298)

- **VERIFIED API:** `Evaluation` (`dataset`, `subject(from:)`, `evaluators`, `aggregateMetrics(using:)`), `ModelSample`, `ArrayLoader`, `Metric` (`.passing`, `.failing`, `.scoring`), `Evaluator`, `MetricsAggregator`, `EvaluationResult`, `ModelJudgeEvaluator`, `ScoreDimension`, `SampleGenerator`, `@Test(.evaluates(...))`. https://developer.apple.com/documentation/evaluations , https://developer.apple.com/videos/play/wwdc2026/298/
- **VERIFIED:** needs iOS 27.0 / macOS 27.0 / Xcode 27.0. https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes
- **VERIFIED aggregates:** mean, median, mode, min, max, standard deviation, variance, `custom(of:label:_:)`. https://developer.apple.com/documentation/evaluations/metricsaggregator
- **INFERENCE:** usable from the iOS 27 test target, not from `swift test` on the macOS 26.6 host. Band hit rate = mean of a pass/fail metric; MAE = mean of a scoring metric; Spearman needs pairs from `result.detailed`. No option for repeated trials found.

### 1.6 Confidence and classification accuracy

- **VERIFIED:** no logprobs in the framework symbols. **THIRD-PARTY:** "The framework exposes no logits". https://github.com/john-rocky/coreai-kit/pull/50
- **VERIFIED:** sampling modes `.greedy`, `.random(top:seed:)`, `.random(probabilityThreshold:seed:)`. https://developer.apple.com/documentation/foundationmodels/generationoptions/samplingmode-swift.struct
- **INFERENCE:** a vote needs `random` sampling with different seeds; greedy repeats one answer.
- **THIRD-PARTY (preprint, Aug 2026):** self-reported confidence AUROC 0.47; k=5 agreement gave 82.8 % accuracy on the 28.2 % of questions it answered (factual QA). https://www.beri.net/article/apple-on-device-foundation-model-audit-confabulation-consistency-sampling
- **THIRD-PARTY:** a "yes" bias on yes/no questions: 53 yes where 35 were expected, of 74 (coreai-kit PR #50).
- **VERIFIED few-shot advice:** "between 2-15 examples, and keep each example as simple as possible" (prompting page); WWDC25 248: "less than five examples". **Local result:** 3 anchors did not help scoring (§7.2, variant C).
- **VERIFIED:** "break up the steps across multiple LanguageModelSession instances" (prompting page).

### 1.7 Benchmarks

- **VERIFIED:** Apple calls the model competitive with "Qwen-3-4B and Gemma-3-4B in English". https://machinelearning.apple.com/research/apple-foundation-models-2025-updates
- **THIRD-PARTY:** JevBench (231 questions): 87.5 % easy, 72.2 % standard, 38.7 % hard; median latency 0.36 s; 4 guardrail refusals (coreai-kit PR #50).
- **Not found:** a public benchmark for extraction or classification.

---

## 2. GitHub

Verified = the agent opened the repo or file. Stars and dates as of 2026-09-28. Porting code or lists from an MIT or Apache-2.0 repo requires keeping its license notice.

### 2.1 Foundation Models projects

| Repo | License | What to take | Fit |
|---|---|---|---|
| [anthropics/ClaudeForFoundationModels](https://github.com/anthropics/ClaudeForFoundationModels) (307★) | Apache-2.0 | `ClaudeLanguageModel` conforms to the iOS 27 `LanguageModel` protocol: `LanguageModelSession` and `@Generable` stay unchanged. Auth: `.appAttest(clientID:)` (device), `.apiKey` (simulator), `.proxied`. `ErrorMapper.swift` maps API errors to `LanguageModelError`; `fallbacks:` retries on other Claude models. Beta. | V2 fallback for refusals and Russian postings (CLAUDE.md §9); needs network |
| [getdictus/dictus-ios](https://github.com/getdictus/dictus-ios) (36★) | MIT | `DictusCore/Sources/polish-harness/`: a `swift run` eval CLI with JSON fixtures, `--runs N`, prompt A/B, and a `prompt` command that prints the exact bytes. Issue #518: one English label (`Input:`) right before the user text gave 10/10 false `unsupportedLanguageOrLocale`; no label or `<TRANSCRIPT>` tags gave 0/10. | Same shape as our host harness; the label finding matches threadly |
| [rryam/FoundationModelsKit](https://github.com/rryam/FoundationModelsKit) (162★) | MIT | `Errors/FoundationModelErrorProjection.swift` keeps error categories stable across iOS 26/27; `Runtime/FoundationModelEnvironmentDiagnostics.swift` flags an SDK / simulator / host mismatch. | Copy the ideas, not the dependency (CLAUDE.md rule 9) |
| [rudrankriyam/FoundationModelsBench](https://github.com/rudrankriyam/FoundationModelsBench) (6★) | MIT | Deterministic grading; a safety suite that counts false positives. README: "Do not publish Simulator results." Its Evaluations package needs macOS 27 + Xcode 27. | Confirms: simulator numbers are a proxy |
| [mozilla-mobile/firefox-ios](https://github.com/mozilla-mobile/firefox-ios) | MPL-2.0 | `BrowserKit/.../AppleIntelligence/LanguageModelSessionAdapter.swift`: session behind a protocol, opt-in permissive guardrail. | Same shape as `LLMClient` |

### 2.2 Error reports

- `.permissiveContentTransformations` stops `guardrailViolation` only for `String` output (Apple doc mirror Averyy/apple-dev-docs; [CharlesWiltgen/Axiom](https://github.com/CharlesWiltgen/Axiom) `foundation-models-guardrails.md`, which recommends the Feedback category `triggeredGuardrailUnexpectedly`).
- henrypldev/react-native-foundation-models#20 lists the iOS 27 `LanguageModelError` cases.
- **No public report** of "unknown special token: com.apple.fm.language.safety_guardrail" in GitHub issues or code.

### 2.3 Skill lexicons (for `SkillTiers` and per-resume lists)

| Source | License | Content | Verdict |
|---|---|---|---|
| [strelov1/freehire](https://github.com/strelov1/freehire) `internal/dict/skilltag/` (776★, Go) | MIT | `dictionaries.go` word and phrase aliases, `labels.go`, `descriptions.tsv`; about 750–920 skills incl. llm, rag, langchain, llamaindex, pgvector, mcp, prompt engineering, fine-tuning. Ambiguous acronyms (`RAG`) match only inside a category. | **Best fit:** convert to a JSON resource |
| [MIND-TechAI/MIND-tech-ontology](https://github.com/MIND-TechAI/MIND-tech-ontology) | MIT | `__aggregated_skills.json` (2.4 MB): 3 333 skills with `synonyms` and `impliesKnowingSkills`; has LangChain, LlamaIndex, DSPy, vLLM. | Per-resume skill lists (Phase 1) |
| O*NET 30.1 `Technology Skills.txt` | CC BY 4.0 (inference) | TSV with a "Hot Technology" flag; PyTorch, Hugging Face, Kubernetes; no LangChain, FastAPI, LlamaIndex in the checked part. | Too slow to follow the LLM tool market |
| Discarded | – | SkillNER (EMSI data, no LLM terms, needs spaCy); ESCO (no Russian, occupation phrases); JobBERT (110M model, needs Core ML conversion); Lightcast Open Skills (API key, redistribution unverified). | – |

### 2.4 Eligibility, work mode and title detectors

- **freehire `internal/dict/location/`** (MIT), each file with a `_test.go` table and precision notes:
  - `clearance.go`: US/UK/AU phrases, a regex for "Clearance: <value>" fields, denial words.
  - `eligibility.go`: US/EU/UK-only phrases, "authorized to work in".
  - `workmode.go`: anchored remote / hybrid / onsite phrases, with a guard against "work from anywhere" travel perks.
  - `region_scope.go`, `residence.go`.
  - **Use:** a second source of patterns and test cases for `Grounding.statedRestriction` and the remote-policy words.
- **freehire `internal/dict/classify/dictionaries.go`:** job title → `ai_engineering` / `ml_ai` / `data_engineering` (English, Russian, Japanese). **Use:** a deterministic signal next to `roleFocus` / `llmWork`.
- maccydee/job-radar (MIT, Python) `jobradar/screen.py`: location string → country.
- Discarded: New-Grad-Jobs `enrich.py` (plain substring lists), f1-filter, SponsorScan and sec-clearance-check-ext (0★), Europe-Visa-Sponsorship-Jobs (no license).

### 2.5 Matching

- **freehire `internal/candidate/jobmatch/jobmatch.go` + `internal/dict/skilladjacency/`:** each job skill is exact, adjacent (the candidate has a listed neighbour) or missing; adjacent counts 0.5. Spec: IDF-weighted cosine over skill slugs, no embeddings. **Use:** replaces our flat "unknown = 0.5" with "adjacent = 0.5, missing = 0.25".
- **career-ops-hq/career-ops** (72 920★, MIT): `evals/golden/*.json` + `evals/fixtures/` replay with frozen labels and a tolerance band. Borrow the layout only; its LLM gives one overall score.
- Discarded: Resume-Matcher (LLM tool now), pyresparser (GPL-3.0), skills-ml / skills-api (stale), nestauk/ojd_daps_skills (Python + spaCy).

---

## 3. Experiments run from this research

### 3.1 Evidence quote before `llmWork` (web finding 1.1) — rejected

- **Change:** a `llmEvidence` field (the posting's LLM / generative AI / agent sentence, word for word, or empty) before `roleFocus` and `llmWork`. Swift raises `none` to `part` when the quote occurs in the text and names an LLM term. Standalone host harness, dev set only.
- **Result on dev:**

| Variant | Within 1 | Exact | MAE | Bias | Spearman |
|---|---|---|---|---|---|
| D (shipped digest) | 10/10 | 6 | 5.7 | +2.5 | 0.88 |
| D + evidence quote + Swift floor | 9/10 | 5 | 7.0 | +1.6 | 0.77 |

- **Why:** sandboxly moved from `llmApplications/core` to `fullStack/none` although its quote names "AI agents". nxt-partner improved (`backend/part`). For postings without LLM work the model wrote the word "none" instead of an empty string.
- **Holdout not used:** dev got worse, so the variant stopped there.

### 3.2 Title aliases as an `llmWork` floor (GitHub finding 2.4) — not run

- Checked by hand against the holdout misses: stayloft's title has no AI word, so a title rule cannot fix it. "Senior AI Engineer" would raise k-vanta (closer to `/rank`) but also lattice-motion and northvale-databricks (further). Expected net effect ≈ 0.

### 3.3 Guardrail retry without visa lines (web 1.4, GitHub 2.2) — works on the host

- **Case:** sandboxly + "We are unable to sponsor work visas for this position." → `guardrailViolation` on the host and on the simulator.
- **Retry:** remove every line that contains "visa" or "sponsor" from the model input only; `grounded(in:)` still reads the full text.
- **Result:** extraction passes; eligibility FLAG, quote "We are unable to sponsor work visas for this position.".
- **Built** (`Truncator.droppingVisaLines`, one retry in `FoundationModelsClient.generate`). Simulator `GateInjectionTests`: 17/17, the sandboxly case returns FLAG.
- **Not tested:** variantly (it fails only on the simulator); postings where the blocked phrase is not about visas.

### 3.4 freehire test tables against our gate rules — measured, not built

- **Source:** strelov1/freehire commit `900408d7e3172193966064f096b4dbf4e5d78b2a`, `internal/dict/location/*_test.go` (MIT). 102 labelled eligibility cases, 21 work-mode cases, 11 remote-denial rows. A Python port of `statedRestriction`, `sentences` and `policyWords` gave the same output as the Swift functions on all 102 cases.
- **Current rules:**

| Rule | Positives | Recall | False positives (of 42 negatives) |
|---|---|---|---|
| citizenshipOrPRRequired | 13 | 13/13 | 3 ("good corporate citizen", equal-opportunity text, "without US citizenship") |
| clearanceRequired | 34 | 18/34 | 6 ("Medical clearance is required", "Clearance Required: No", negations) |
| authorizationRequired | 16 | 13/16 | 0 |
| **Final stance** | 102 | **74/102** | – |

- **Missed clearance forms:** "SC cleared", "BPSS", "NV1", "eDV", "positive vetting", "full scope polygraph", "Clearance: Secret" fields.
- **Work mode:** the expected list matches 15 of 21 (misses: work-from-home, home-based, telecommute, virtual position, "3 days in the office"); 9 of 11 remote-denial rows still keep a claimed `.remote`.
- **Proposed regex changes (7 items, Swift-checked): 101/102 with 0 new false positives.** Largest gains: clearance scheme names (+12), a negation exemption for citizenship and clearance (+6), labelled "Clearance: …" fields (+5).
- **Risk in the negation exemption:** it checks the whole sentence, so "must not have X and must be a US citizen" would become a silent PASS. Review it before it ships.
- **Limits:** hand-picked unit rows, not a production sample; the work-mode changes ran in Python only.
- **Files:** `scratchpad/freehire/` (`cases.json`, `eval.py`, `proposals2.py`, `check2.swift`, `prop_rx.json`), session scratchpad, not in the repo. Porting the phrase lists needs the MIT notice.
