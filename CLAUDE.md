# JobScout — iOS companion for a job-search workflow

You are Claude Code working in a fresh Xcode project. Build **JobScout**, an iOS 27 app that
uses Apple's on-device Foundation Models to parse a job posting, run the fit rubric from the
candidate's existing job-search repo, and keep a tracker. Work **test-first** on every step.

Read this file fully before the first tool call. Then start at **Step 0** and stop at the end
of each step to report: tests written, tests green, what is next.

---

## 1. Product scope (V1 only)

V1 = "Parse + Score + Track". Nothing else.

| In V1 | Out of V1 (do not build) |
|---|---|
| Share a URL or text into the app from Safari / LinkedIn / Telegram | Cover letters, CV bullets, PDF export |
| Fetch the posting body (Greenhouse, Lever, Ashby JSON; any other URL as HTML → text) | Scheduled scraping of Telegram channels or LinkedIn |
| Extract structured fields with the on-device model (`@Generable`) | Company research, salary lookup, web search |
| Deterministic gates in Swift: eligibility, language, location | Russian-language postings (on-device model has no Russian) |
| Fit score (4 weighted dimensions) + verdict band + strengths / gaps | Private Cloud Compute and Claude (V2, see §9) |
| Tracker with the canonical status vocabulary; export CSV + JSON compatible with the repo | Push notifications, widgets, iCloud sync |

Target: **iOS 27**, Swift 6, SwiftUI, SwiftData, Swift Testing. Devices with Apple Intelligence
(iPhone 15 Pro and later). Device language and Siri language must be a supported language;
use **English** for development.

---

## 2. Source of truth — port from the existing repo, do not reinvent

Source: the author's private job-search repo (Claude Code skills and Python tools; not part of this repository). Paths in this table are relative to its root.

| File | What to take | Where it goes in JobScout |
|---|---|---|
| `CLAUDE.md` (sections "Candidate Profile", "Technical Skills", "Deal-breakers") | Facts about the candidate. Compress to **≤ 900 tokens** (measure with `tokenCount(for:)`). Keep numbers, drop prose. | `Core/Resources/profile_compact.md` and `profile_full.md` |
| `.claude/skills/job-application-assistant/04-job-evaluation.md` | Eligibility Gate table, Language Gate table, 5 dimensions with the strong/moderate/weak lists, Location rules | `Core/Rubric/*.swift` + `Core/Resources/rubric_compact.md` (≤ 700 tokens) |
| `.claude/commands/rank.md` line 81–82 | Weights: Technical 30 %, Experience 25 %, Behavioral 15 %, Career 30 %. Location is unweighted. Bands: Strong Fit ≥ 75, Good 60–74, Moderate 45–59, Weak 30–44, Poor < 30 | `Core/Rubric/Scoring.swift` |
| `.claude/commands/rank.md` "Step 2" JSON block | The per-job result schema (`scores`, `location_verdict`, `language_gate`, `language_note`, `deadline`, `strengths`, `gaps`, `language`) | `Core/Models/FitEvaluation.swift` |
| `tools/job_key.py` | `make_key(company, title, url)`: NFKD → ASCII → lowercase → non `[a-z0-9]` → `-`; company cap 40, title cap 60, sha1 6-char suffix when capped; non-Latin fallbacks | `Core/Dedup/JobKey.swift`. Port the docstring examples as tests. |
| `.claude/commands/outcome.md` "## Tracker status vocabulary" | `drafted, applied, interview, offer, hired, rejected, no_response, offer_declined, withdrawn`. Final = `hired, rejected, no_response, offer_declined, withdrawn`. Read-tolerate legacy `no response` / `offer declined`; never write them. | `Core/Tracker/TrackerStatus.swift` |
| `job_search_tracker.csv` header | `date,company,sector,role,role_type,channel,status,contact_person,fit_rating,notes,cv_file,cover_letter_file,source,deadline` | `Core/Export/CSVExporter.swift` |
| `job_scraper/seen_jobs.json` | Entry shape: `title, company, url, first_seen, posted_date, deadline, fit, status, portal, source, location, rank_score, rank_verdict, rank_date, location_verdict, language_gate, strengths, gaps` | `Core/Export/SeenJobsExporter.swift` |
| `documents/applications/tbd_senior_ai_engineer/job_posting.md` + tracker row `fit_rating=80` | First eval fixture with a known expected score | `Tests/Fixtures/Eval/` |

Candidate constraints that the gates must encode (from `04-job-evaluation.md` and `CLAUDE.md`):
- Based in Almaty, Kazakhstan (GMT+5). Not an EU/US citizen or permanent resident.
- Languages: English (fluent), Russian (native), Tatar (native).
- Remote worldwide; relocation OK only with employer support and visa sponsorship.
- FAIL: citizenship / PR requirement, security clearance, on-site abroad without sponsorship.
- FLAG: "must be located in <country>" without a sponsorship statement; frequent travel.
- Rate floor for part-time / freelance: 35 USD/h.

---

## 3. Rules for this project

1. **Red → green → refactor.** Write the failing test first. Do not write production code without a test that needs it.
2. **The model sits behind a protocol.** `LLMClient` has two implementations: `FoundationModelsClient` (real) and `FakeLLMClient` (returns fixtures). All Core tests run with the fake on a Mac without Apple Intelligence.
3. **Core is a Swift package with no UIKit / SwiftUI imports.** It compiles for macOS and iOS. UI lives in the app target only.
4. **Gates are deterministic Swift.** The model extracts fields; Swift decides PASS / FAIL / FLAG. A prompt change must never change a gate verdict.
5. **Budget every prompt.** Read `SystemLanguageModel.default.contextSize` at runtime. Sum instructions + prompt with `tokenCount(for:)` and leave ≥ 600 tokens for output. On a 4096-token model use `profile_compact.md`, on 8192 use `profile_full.md`.
6. **No secrets in the binary.** No Anthropic API key in source or Info.plist. V2 uses App Attest.
7. **No scraping of LinkedIn from the app.** Accept a LinkedIn URL from the share sheet, fetch it once, and stop there. Use ATS JSON APIs (Greenhouse, Lever, Ashby) whenever the URL points at one.
8. **Prompts are files, not string literals.** `Core/Resources/prompts/*.md`. A golden test pins each rendered prompt, so drift is visible in a diff.
9. **Keep it small.** Standard library first. One dependency maximum in V1, and only if a test shows the standard library cannot do the job (HTML → text is the likely case).
10. **Report honestly.** If a test fails or the model is unavailable, say so with the output. Do not mark a step done with red tests.

---

## 4. Architecture

```
JobScout.xcworkspace
├── Core/                     Swift package, platform-agnostic, 100 % unit-testable
│   ├── Models/               JobPosting (@Generable), FitEvaluation, TrackedJob (SwiftData)
│   ├── Rubric/               Gates.swift, Scoring.swift, Bands.swift
│   ├── Dedup/                JobKey.swift
│   ├── Fetch/                ATSDetector, GreenhouseClient, LeverClient, AshbyClient, HTMLText
│   ├── LLM/                  LLMClient protocol, PromptBudget, PromptRenderer, FakeLLMClient
│   ├── Export/               CSVExporter, SeenJobsExporter
│   └── Resources/            profile_*.md, rubric_compact.md, prompts/*.md
├── JobScoutApp/              SwiftUI app: Inbox, JobDetail, Tracker, Settings
│   └── LLM/FoundationModelsClient.swift   (imports FoundationModels; the only file that does)
├── ShareExtension/           receives URL / text → writes to the App Group store → opens app
└── Tests/
    ├── CoreTests/            Swift Testing, runs everywhere
    ├── Fixtures/             ATS JSON, HTML pages, eval postings (+ expected bands)
    └── DeviceTests/          @Test(.tags(.onDevice)) — skipped when the model is unavailable
```

Data flow: Share → `IncomingItem` (App Group) → `PostingFetcher` → `plainText` → `LLMClient.extract` →
`JobPosting` → `Gates.run` → `LLMClient.score` → `FitEvaluation` → `Scoring.overall` → `TrackedJob`.

Key types (write these exactly; tests depend on the names):

```swift
// Core/Models/JobPosting.swift
import FoundationModels   // only for the macros; Core still compiles for macOS 26+

@Generable
struct JobPosting: Codable, Equatable, Sendable {
    @Guide(description: "Job title as written in the posting") var title: String
    @Guide(description: "Employer name; empty string if the posting hides it") var company: String
    @Guide(description: "City and country, or 'Remote'") var location: String
    @Guide(description: "Remote policy") var remotePolicy: RemotePolicy
    @Guide(description: "Employment type") var employmentType: EmploymentType
    @Guide(description: "Countries or time zones the candidate must be in; empty if none") var locationRequirement: [String]
    @Guide(description: "Visa or work-authorization statement") var visaSponsorship: VisaStance
    @Guide(description: "Languages the job itself requires, with level words as written") var requiredLanguages: [LanguageRequirement]
    @Guide(description: "Technologies named in requirements, lowercase") var stack: [String]
    @Guide(description: "Years of experience required, 0 if not stated") var minYearsExperience: Int
    @Guide(description: "Salary or rate exactly as written; empty if absent") var compensation: String
    @Guide(description: "Application deadline as YYYY-MM-DD; empty if absent") var deadline: String
}

@Generable enum RemotePolicy: String, Codable, Sendable { case remote, hybrid, onsite, unspecified }
@Generable enum EmploymentType: String, Codable, Sendable { case fullTime, partTime, contract, freelance, unspecified }
@Generable enum VisaStance: String, Codable, Sendable { case sponsors, citizenshipOrPRRequired, clearanceRequired, authorizationRequired, silent }
@Generable struct LanguageRequirement: Codable, Equatable, Sendable { var language: String; var level: String }

// Core/Models/FitEvaluation.swift
@Generable
struct DimensionScores: Codable, Equatable, Sendable {
    @Guide(description: "0-100 per the rubric", .range(0...100)) var technical: Int
    @Guide(description: "0-100", .range(0...100)) var experience: Int
    @Guide(description: "0-100", .range(0...100)) var behavioral: Int
    @Guide(description: "0-100", .range(0...100)) var career: Int
    @Guide(description: "1-3 bullets grounded in the posting text", .count(1...3)) var strengths: [String]
    @Guide(description: "1-3 honest bullets", .count(1...3)) var gaps: [String]
}

enum Verdict: String, Codable { case pass = "PASS", fail = "FAIL", flag = "FLAG" }
enum Band: String, Codable, CaseIterable { case strong = "Strong Fit", good = "Good Fit", moderate = "Moderate Fit", weak = "Weak Fit", poor = "Poor Fit" }

struct FitEvaluation: Codable, Equatable, Sendable {
    var scores: DimensionScores
    var overall: Int              // computed by Scoring, never by the model
    var band: Band
    var eligibility: Verdict; var eligibilityNote: String?
    var languageGate: Verdict;  var languageNote: String?
    var locationVerdict: Verdict; var locationNote: String?
}

// Core/LLM/LLMClient.swift
protocol LLMClient: Sendable {
    var contextSize: Int { get }
    func tokenCount(_ text: String) -> Int
    func extract(postingText: String) async throws -> JobPosting
    func score(posting: JobPosting, postingText: String) async throws -> DimensionScores
}
```

If `@Guide(.range)` / `.count` do not compile on the installed SDK, check the current `Guide`
macro signature in Xcode (`FoundationModels` → `Guide`) and keep the description text.

---

## 5. Step-by-step MVP plan (each step: test first → implement → verify → report)

### Step 0 — Project bootstrap (no product code)
- Create the workspace, `Core` Swift package (platforms: iOS 27, macOS 26), app target, share extension target, App Group `group.<bundle-id>`.
- Add Swift Testing targets. Confirm one trivial `@Test` runs from the CLI:
  `xcodebuild test -scheme JobScout -destination 'platform=iOS Simulator,name=<pick from xcrun simctl list devices available>'`
- Install XcodeBuildMCP for headless build / test / simulator control: `npm install -g xcodebuildmcp@latest`, then `claude mcp add xcodebuildmcp -- xcodebuildmcp mcp`.
- Add `Tests/Fixtures/` and a `Fixture.load(_:)` helper.
- Add a launch-time capability probe in the app: `SystemLanguageModel.default.availability`, `.contextSize`, `.supportedLanguages`. Show it on the Settings screen. On `.unavailable(reason)` show the reason text.
- Done when: CLI test run is green, the probe screen shows availability + contextSize on the simulator or device.
- Read: Foundation Models overview, "Generating content and performing tasks with Foundation Models", Swift Testing (links in §8).

### Step 1 — JobKey (pure function, port of `tools/job_key.py`)
Tests first (`Tests/CoreTests/JobKeyTests.swift`), use `@Test(arguments:)`:
- `("Acme Corp", "SOC Analyst (L2)") → "acme-corp_soc-analyst-l2"`
- `"deloitte_junior-cybersecurity-analyst-(ot/iot)"`-style titles produce no `/`, `(`, `,`.
- Two long titles that share the first 60 chars produce different keys; the same long title produces the same key twice.
- Non-Latin title + URL with a 6+ digit id → `<company>_<id>`.
- Empty company → `unknown-company_<title>`.
- `isCanonical` accepts `^[a-z0-9][a-z0-9-]*_[a-z0-9][a-z0-9-]*$` only.
Implement with `String.applyingTransform(.stripDiacritics)` / `decomposedStringWithCompatibilityMapping` + ASCII filter + `Insecure.SHA1` from CryptoKit.
Done when: every docstring example from the Python file passes.

### Step 2 — Tracker status + CSV / JSON export
Tests first:
- `TrackerStatus(rawValue:)` accepts the 9 canonical values and the 2 legacy space forms; `.isFinal` is true for the 5 final values including legacy forms.
- `CSVExporter` writes the exact 14-column header from `job_search_tracker.csv`; a `notes` value with a comma, a quote and a newline round-trips through a CSV parser test.
- `SeenJobsExporter` writes `{"seen": {<key>: {...}}}` with the field names from §2; decode the existing `job_scraper/seen_jobs.json` fixture without error.
Implement `TrackedJob` as a `@Model` (SwiftData) with a `status: String` column + typed accessor.
Done when: an exported CSV appended to the real tracker file parses with Python's `csv` module (run it via Bash).

### Step 3 — Posting fetch: ATS detection + JSON clients
Tests first, with saved fixtures (fetch each once with `curl`, store under `Tests/Fixtures/ATS/<vendor>_<date>.json`):
- `ATSDetector.detect(url)`: `boards.greenhouse.io/<token>/jobs/<id>` → `.greenhouse(token,id)`; `jobs.lever.co/<site>/<uuid>` → `.lever(site,id)`; `jobs.ashbyhq.com/<board>/<uuid>` → `.ashby(board,id)`; anything else → `.html`.
- `GreenhouseClient.decode(fixture)` yields `title`, `location.name`, `content` (HTML-entity-encoded → decode), `absolute_url`, `updated_at`.
- `LeverClient.decode(fixture)` yields `text`, `descriptionPlain`, `lists[].text/content`, `categories.location`, `categories.commitment`, `hostedUrl`.
- `AshbyClient.decode(fixture)` yields `title`, `location`, `isRemote`, `descriptionPlain`, `jobUrl`, `publishedAt`, `employmentType`.
- Every client returns the same `FetchedPosting { title, company, url, plainText, postedAt? }`.
Endpoints (no auth):
- Greenhouse: `GET https://boards-api.greenhouse.io/v1/boards/{board_token}/jobs/{job_id}?content=true`
- Lever: `GET https://api.lever.co/v0/postings/{site}?mode=json` is documented (EU tenants: `api.eu.lever.co`). A single-posting form `/v0/postings/{site}/{id}` is **not verified** — check the README first; if absent, list and filter by `id`.
- Ashby: `GET https://api.ashbyhq.com/posting-api/job-board/{board}?includeCompensation=true`, then pick the job by URL (a real board from the candidate's scrapes: `variantly`).
Done when: all three decoders pass on fixtures and one live call each succeeds in a `.tags(.network)` test.

### Step 4 — HTML → plain text for non-ATS URLs
Tests first: three saved HTML fixtures (one LinkedIn public job page, one company careers page, one hh.ru page) → output contains the requirements paragraph, contains no `<`, no `script` content, collapses whitespace.
Implement: try `NSAttributedString(data:options:[.documentType: .html])` on the main actor first. If a test shows it drops the body or is > 1 s on a fixture, add SwiftSoup as the single allowed dependency and record why in this file.
Done when: fixtures pass and a `Truncator` test shows the "requirements / qualifications / what you'll need" section survives when the text is cut to a token budget.

### Step 5 — Deterministic gates (no model)
Tests first (`GatesTests.swift`), one `@Test(arguments:)` table per gate, cases taken from the tables in `04-job-evaluation.md`:
- Eligibility: `visaSponsorship == .citizenshipOrPRRequired` → FAIL with quoted note; `.clearanceRequired` → FAIL; `.sponsors` → PASS; `.silent` → PASS + note "unverified"; `.authorizationRequired` → FLAG.
- Language: required language not in {English, Russian, Tatar} → FAIL; English with "native" or "C2" → FLAG; English with "fluent" / "professional" / unspecified → PASS.
- Location: `.remote` → PASS; `.hybrid`/`.onsite` in Almaty → PASS; `.onsite` elsewhere with `.sponsors` → PASS, otherwise FLAG; `locationRequirement` names a country ≠ Kazakhstan and policy is remote → FLAG.
Done when: table tests pass and a fuzz-style test feeds 200 random `JobPosting`s and never throws.

### Step 6 — Extraction with the on-device model
Tests first:
- `PromptRendererTests`: rendering `prompts/extract.md` with a posting text yields the golden file `Tests/Fixtures/Golden/extract_prompt.txt` (update goldens only on purpose).
- `PromptBudgetTests`: with `contextSize = 4096`, instructions of 1 500 tokens and output reserve 600, a 3 000-token posting is truncated to ≤ 1 996 tokens using the `Truncator` from Step 4.
- `FakeLLMClient` returns a fixture `JobPosting`; the pipeline test proves `extract` output reaches `Gates`.
- `DeviceTests/ExtractionTests.swift`, tagged `.onDevice`, skipped unless `SystemLanguageModel.default.isAvailable`: run the real model on `job_posting.md` and assert `title` contains "Senior AI Engineer", `remotePolicy == .remote`, `stack` contains "python".
Implement `FoundationModelsClient`:
```swift
let model = SystemLanguageModel.default
let session = LanguageModelSession(model: model, instructions: Instructions(renderedInstructions))
let response = try await session.respond(to: postingText, generating: JobPosting.self)
```
Catch `LanguageModelError.contextSizeExceeded` → retry once with a tighter truncation; catch the unsupported-language / guardrail cases (list the exact cases from `LanguageModelError` in Xcode) → surface a user-readable reason. Call `session.prewarm()` when the detail screen opens.
Done when: fake-backed tests are green everywhere and the device test passes on the simulator (macOS 26+ host with Apple Intelligence on) or on the phone.

### Step 7 — Scoring
Tests first:
- `Scoring.overall(technical: 80, experience: 70, behavioral: 60, career: 80) == 75` (0.30·80 + 0.25·70 + 0.15·60 + 0.30·80 = 74.5 → round half up = 75; pin the rounding rule in the test).
- `Band(for:)` boundaries: 75 → strong, 74 → good, 60 → good, 59 → moderate, 45 → moderate, 44 → weak, 30 → weak, 29 → poor.
- Any gate FAIL forces `band = .poor` and keeps the dimension scores (the repo treats FAIL as a veto, not as a score of 0).
- Golden prompt test for `prompts/score.md` (rubric_compact + profile + posting summary, not the full text).
- `DeviceTests/EvalTests.swift`, `.onDevice`: for each fixture in `Tests/Fixtures/Eval/` (posting text + `expected_band`), the produced band equals the expected band or an adjacent one. Build the set from `job_posting.md` (expected Strong, tracker says 80) plus up to 9 live **English** URLs from `seen_jobs.json` that carry `rank_score`; fetch with `curl`, store text + expected band + source URL + fetch date. Report per-fixture results in a table; tolerance is one band.
Done when: pure tests green; eval table printed; ≥ 7 of 10 within tolerance (record the real number; do not tune goldens to pass).

### Step 8 — Share Extension → App Group → app
Tests first:
- `IncomingItemParser`: `NSItemProvider` payloads of `public.url`, `public.plain-text` (a pasted URL arrives as text — parse it as URL), and text containing a URL + description → `IncomingItem { url?, text? }`.
- The item is written to the App Group SwiftData store and is visible to the app target (integration test on the simulator).
Implement:
- `Info.plist` → `NSExtension` → `NSExtensionAttributes` → `NSExtensionActivationRule` as a dictionary: `NSExtensionActivationSupportsWebURLWithMaxCount = 1`, `NSExtensionActivationSupportsText = true`.
- Share both targets' SwiftData store via the App Group container (`ModelConfiguration(groupContainer: .identifier("group.<bundle-id>"))`).
- Extension UI: one screen, "Add to JobScout", then `extensionContext.completeRequest`. Do the fetch and the model call in the **app**, not in the extension (memory limits).
Done when: sharing a Greenhouse URL from Safari on the simulator creates an Inbox row.

### Step 9 — App UI (SwiftUI)
Screens: **Inbox** (unprocessed items, "Parse" button, progress via `session.isResponding`), **Job detail** (extracted fields, gate verdicts with quoted notes, dimension scores, band, strengths / gaps, "Add to tracker"), **Tracker** (list grouped by status, status picker limited to the canonical vocabulary, export CSV / JSON via `ShareLink` and Files), **Settings** (capability probe from Step 0, profile variant in use, token budget).
Tests: view-model tests only (state transitions: `idle → fetching → extracting → scoring → done | failed(reason)`). No UI snapshot tests in V1.
Mark model output as AI-generated and editable (Apple HIG "Generative AI"). Every field is editable before "Add to tracker".
Done when: the full path Share → Parse → Score → Tracker → Export works on a device with a real posting, and the exported CSV row appends cleanly to the repo tracker (Step 2 check).

### Step 10 — Hardening
- Eligibility FAIL shows the quoted wording, never a silent drop (rule from `04-job-evaluation.md`).
- Unsupported device / language: Settings explains it; Inbox still stores items.
- Duplicate detection via `JobKey` before insert; show "already tracked" with the existing row.
- Token budget telemetry in Settings: last prompt tokens, contextSize, truncation applied yes/no.
- Run the whole suite from the CLI, paste the summary line into the final report.

---

## 6. Definition of done (MVP)

- `xcodebuild test` green for `CoreTests` on a Mac with no model; `DeviceTests` green on the simulator or phone.
- Eval table with ≥ 10 fixtures and the real hit rate.
- Share → Tracker path demonstrated on a device with one Greenhouse, one Lever, one Ashby and one plain-HTML posting.
- Exported `job_search_tracker.csv` rows and `seen_jobs.json` entries load in the existing Python tools (`python3 tools/job_key.py --audit <exported.json>` exits 0).
- No secrets in the repo; `git grep -i "sk-ant"` returns nothing.

---

## 7. Test conventions

- Swift Testing only: `@Suite`, `@Test`, `#expect`, `#require`, `@Test(arguments:)` for tables.
- Tags: `extension Tag { @Tag static var onDevice: Self; @Tag static var network: Self }`. Device tests start with
  `guard SystemLanguageModel.default.isAvailable else { return }` and print the skip reason.
- Fixtures are immutable files with the fetch date in the name. Goldens change only in a commit whose message starts with `golden:`.
- Naming: `<Type>Tests.swift`, one behavior per test, test name states the expected outcome.
- CI later: GitHub Actions `macos-26` runner, `CoreTests` only (no Apple Intelligence on runners).

---

## 8. Where to look (verified 2026-09-27)

Apple — Foundation Models
- Framework home: https://developer.apple.com/documentation/foundationmodels
- Generating content and performing tasks: https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models
- Guided generation (`@Generable`, `@Guide`): https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation
- Managing the context window (`contextSize`, `tokenCount`): https://developer.apple.com/documentation/foundationmodels/managing-the-context-window
- Languages and locales (`supportedLanguages`, `supportsLocale`): https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models
- Tool calling (`Tool` protocol; not needed in V1): https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling
- Safety and guardrails: https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output
- Evaluating prompts (Apple's eval workflow, use it for Step 7): https://developer.apple.com/documentation/foundationmodels/evaluating-prompts-to-measure-performance-and-improve-model-responses
- Runtime performance (Instruments): https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app
- `SystemLanguageModel` (availability, contextSize, tokenCount, supportedLanguages): https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- `LanguageModelSession` (respond, streamResponse, prewarm, transcript, usage): https://developer.apple.com/documentation/foundationmodels/languagemodelsession
- Multimodal (screenshot of a posting, V2): https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting
- Private Cloud Compute (V2): https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute
- WWDC25 286 Meet the Foundation Models framework: https://developer.apple.com/videos/play/wwdc2025/286/
- WWDC25 301 Deep dive: https://developer.apple.com/videos/play/wwdc2025/301/
- WWDC25 248 Prompt design & safety: https://developer.apple.com/videos/play/wwdc2025/248/
- WWDC26 241 What's new (8192-token on-device context, PCC, `LanguageModel` protocol): https://developer.apple.com/videos/play/wwdc2026/241/
- HIG Generative AI: https://developer.apple.com/design/human-interface-guidelines/generative-ai
- Apple Intelligence devices and languages: https://support.apple.com/en-us/121115

Apple — testing, data, extensions
- Swift Testing: https://developer.apple.com/documentation/testing
- Parameterized tests: https://developer.apple.com/documentation/testing/parameterizedtesting
- SwiftData: https://developer.apple.com/documentation/swiftdata
- App Groups: https://developer.apple.com/documentation/xcode/configuring-app-groups
- `NSExtensionActivationRule`: https://developer.apple.com/documentation/bundleresources/information-property-list/nsextension/nsextensionattributes/nsextensionactivationrule
- Share extension + SwiftUI + SwiftData walkthrough (third party): https://www.merrell.dev/ios-share-extension-with-swiftui-and-swiftdata/
- App Attest (V2 auth): https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity

Tooling
- XcodeBuildMCP (headless build, test, simulator, screenshots): https://github.com/getsentry/XcodeBuildMCP

Job-board APIs (no auth for reads)
- Greenhouse Job Board API: https://docs.greenhouse.io/job-board.html
- Lever Postings API: https://github.com/lever/postings-api
- Ashby Job Posting API: https://developers.ashbyhq.com/docs/public-job-posting-api

V2 — Claude through the same session API
- Claude for Foundation Models (package, App Attest, proxy, server tools): https://platform.claude.com/docs/en/cli-sdks-libraries/libraries/apple-foundation-models
- Source: https://github.com/anthropics/ClaudeForFoundationModels

---

## 9. V2 notes (do not start before §6 is met)

- **Private Cloud Compute**: `PrivateCloudComputeLanguageModel` + entitlement `com.apple.developer.private-cloud-compute`; 32 K context; free below 2 M first-time downloads. Use for cover-letter drafts and long postings.
- **Claude**: `ClaudeLanguageModel(name: .sonnet5, auth: .appAttest(clientID: "clid_..."))` behind the same `LLMClient`. Use for Russian postings and for the drafter → reviewer loop. `.apiKey` only in the simulator. Rate-limit fallback: catch `LanguageModelError.rateLimited` → on-device model.
- **Screenshot input**: `Attachment` with an image → `JobPosting`; same tests as Step 6 with an image fixture.
- Routing rule to test: English + fits budget → on-device; English + over budget → PCC; non-English → Claude.

---

## 10. Report format after each step

```
Step N — <name>
Tests: <n> written, <n> green, <n> skipped (reason)
Command: <exact xcodebuild or XcodeBuildMCP call>
Changed: <files>
Open: <questions that block the next step, or "none">
Next: Step N+1 — <name>
```

---

## 11. Decisions log

- 2026-09-28, Phase 1 start: the hard-coded candidate is gone from Core. `CandidateProfile` (regions, languages, `SkillTiers`) feeds `Gates.run(_:profile:)` and `FitRubric.scores(digest:stack:skills:)`; persisted as JSON in App Group `UserDefaults` via `ProfileStore`. Resume import: `ResumeImporter.text(from:type:)` — PDF (PDFKit), LaTeX (regex stripper, no lookbehind in Swift regex → manual `%`-comment scanner), plain text. `SkillTiers.derived(from:)` tiers by term frequency against the generic `SkillTiers.catalog` (≥3 → strong, 1–2 → moderate, 0 → weak). The old candidate lives only in tests (`CandidateProfile.fixture`); `profile_*.md` moved to `Tests/Fixtures/Profile/`. UI: Settings → Profile (regions, languages, file/paste resume import, derived-skill summary). Empty profile: language gate flags "unverified", it never silently fails. FitRubric role-focus base/cap tables still encode the applied-LLM career goal (open Phase 1 work). App builds; simulator click-through not done.
- 2026-09-28, grounding: a requiredLanguages entry whose emitted name does not occur in the posting text is dropped (false FAIL from Welcome to the Jungle "FrançaisEnglish (US)" language-switcher chrome, zephyra holdout — found by the eval session). A requirement stated only in a non-English word may drop too: same outcome as the model missing it; grounding never upgrades. 167 tests green.
- 2026-09-28, guardrail: extraction retries once with visa/sponsor lines removed (`Truncator.droppingVisaLines`) after a guardrailViolation — the sandboxly "unable to sponsor work visas" sentence trips Apple's guardrail; grounding still reads the full text, so the eligibility quote survives. GateInjectionTests location cases run on the tbd base only (sandboxly's own "remote, globally distributed" text made injected location sentences ambiguous): 17 cases, bar 16. 169 tests green. Verified by the eval session (2026-09-28): GateInjectionTests 17/17 on the iOS 27 simulator (sandboxly guardrail case now FLAG with quote; the retry fires on iOS 27 only — the macOS 26 host throws a different error type); host dev eval on Phase 1 Core 10/10, exact 6, MAE 6.1, bias +2.9, Spearman 0.84 — identical to pre-Phase-1; halcyon eligibility moved silent → FLAG ("unable to provide visa sponsorship") as a side effect of the retry, expected. Host holdout 24/25, exact 14, MAE 8.3, bias +3.8, Spearman 0.86 — identical to pre-Phase-1; the one miss is threadly on the host (the language retry fires on iOS 27 only; passes on the simulator). Details: docs/MODEL_BEHAVIOR.md §7.3.
- 2026-09-28, real-posting fixes: (1) a sentence supports the permissive `.sponsors` only when it also names visa / work permit / immigration / relocation / international applicants — "We sponsor multiple events" (swatchwell) gave a false hybrid+sponsors location PASS and even became the eligibilityQuote; now grounds to `.silent`. (2) The guardrail retry text is `droppingShortParagraphs(droppingVisaLines(text))` (Holdout2 staffora-solutions: stripping Breezy `%…%` tokens made it worse; dropping 1–3-word paragraphs cleared it). Holdout2 (`Tests/Fixtures/Eval/Holdout2/`, 18 postings, bar 13) added to EvalTests. 172 tests green (incl. a GatesReal swatchwell regression test).
- 2026-09-28, host rerun after the fixes (eval session, docs/MODEL_BEHAVIOR.md §7.3a): dev 10/10 MAE 6.1, Holdout 24/25 MAE 8.3 (threadly fails on the host only — the language retry is iOS 27-only), Holdout2 18/18 MAE 6.0 bias +0.2, GatesReal 16/16 not-PASS (swatchwell now FLAG). Apple's guardrail is not deterministic: staffora-solutions threw guardrailViolation on one greedy host run and parsed on the next — treat single guardrail failures as noise until they repeat.
- 2026-09-28, Low set + sponsors verb guard: `Tests/Fixtures/Eval/Low/` (17 fit:low postings, bar 12) added to EvalTests; host baseline 13/17, MAE 18.1, bias +14.6 (docs/MODEL_BEHAVIOR.md §7.3b) — Low postings are over-scored, calibration open. The permissive `.sponsors` sentence must also contain an offer verb (offer / provide / support / available / we-can-will sponsor): job-board menu chrome "- Jobs with Visa Sponsorship" (anchorline) grounded to a triple PASS. The same guard is deliberately NOT applied to restrictive stances: it would turn bare "- U.S. citizenship" bullets into silent PASSes; a false FAIL at least shows its quote. Known extraction miss: datavane "Polish (Fluent)" not extracted. 175 tests green. Host rerun after the verb guard: scores identical on all five sets; two gate verdicts moved toward /rank (anchorline and hireloom location PASS → FLAG); wraithwork keeps its false citizenship FAIL by design (docs/MODEL_BEHAVIOR.md §7.3b).
- 2026-10-11, public-repo scrub (issue #3): every employer in tests, fixtures and docs maps to a stable fictional name; the map and a leak-check list live in the gitignored `.private/`. Names that are also technologies (Databricks, Mistral, Grafana) are replaced only in the employer's own posting. Founder / recruiter names and the LinkedIn sidebar companies are fictional too. seen_jobs and tracker fixtures are synthetic (one entry per shape). Retired scoring files deleted. Signing moved to `Signing.xcconfig` (example IDs, empty team) + gitignored `Local.xcconfig`; `SharedStore.appGroupID` reads `JobScoutAppGroupID` from Info.plist. LiveATSTests read boards from env vars. Simulator rerun (docs/MODEL_BEHAVIOR.md §7.3c): dev 9/10 exact 6 MAE 6.0 bias +2.4 (variantly guardrail, as before on the simulator), Holdout 25/25 exact 13 MAE 7.9 bias +4.4 (threadly now parses: the real name was a Polish word), Holdout2 18/18 exact 10 MAE 6.2 bias +0.1, Low 13/17 exact 7 MAE 17.9 bias +14.8, GatesReal 16/16 not PASS (new test, bar 15), gate injection 17/17. 199 CoreTests green.

- 2026-09-27, Step 0: `Package.swift` sits at the repo root (package `Core`: target `Core` → `Core/`, test target `CoreTests` → `Tests/CoreTests`, resources `Tests/Fixtures`). SwiftPM forbids target paths outside the package root; this keeps the §4 layout.
- `JobScout.xcodeproj` is generated by xcodegen from `project.yml` and is gitignored. Sources are synced folders: new files join their target without regeneration. Run `xcodegen generate` only after you change `project.yml` (targets, settings).
- Signing: `Signing.xcconfig` sets `APP_BUNDLE_ID = com.example.jobscout`, `APP_GROUP_ID = group.com.example.jobscout` and an empty `DEVELOPMENT_TEAM`; a gitignored `Local.xcconfig` next to it overrides all three (see the comment in `Signing.xcconfig`). Do not change signing in the Xcode UI: regeneration resets it.
- Open `JobScout.xcworkspace`, never the repo folder: the folder has `Package.swift` at its root, so Xcode opens it as the `Core` package (library only, scheme `Core`) and Run builds `Core.o` with no app to launch (2026-09-27). Device build + launch verified from the CLI the same day: `xcodebuild -workspace JobScout.xcworkspace -scheme JobScout -destination 'platform=iOS,id=<device UDID>' -allowProvisioningUpdates build`, then `xcrun devicectl device install app` / `process launch`. Free (Personal Team) signing accepts the App Group.
- §6 device demo on the author's device (iPhone 16e, iOS 27.0, user-reported, 2026-09-27): LinkedIn (HTML path), Greenhouse, Lever and Ashby links shared into the app were parsed. Settings screenshot: model Available, contextSize **4096** (not the 8192 from WWDC26), device language supported, profile_compact, last prompt 2409 tokens, not truncated, App Group store "shared" (Personal Team). `profile_full.md` is unused on this hardware.
- The user builds and runs on the device from Xcode. The device UDID lives in `.xcodebuildmcp/config.yaml` (gitignored); do not use other paired devices.
- Test commands: `swift test` (CoreTests on macOS) and `xcodebuild test -workspace JobScout.xcworkspace -scheme JobScout -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'`.
- The iOS 27.0 simulator uses the host model (macOS 26.6.2): `available`, contextSize 4096. Right after the first boot it reported `modelNotReady` (16:18, 16:20); at 17:02 it reported `available`. If DeviceTests print `skip: … modelNotReady`, wait and rerun.
- XcodeBuildMCP 2.7.0 is registered in Claude Code (local scope, `XCODEBUILDMCP_SENTRY_DISABLED=true`). Defaults are in `.xcodebuildmcp/config.yaml` (gitignored).
- 2026-09-27, Step 2: tracker CSV maps `role` = title, `fit_rating` = `rankScore` (bare number), `source` = posting URL; RFC 4180 quoting, LF, no BOM. `seen_jobs.json` export writes `source: "jobscout"`, `status: "ranked"` when scored else `"new"`, `null` for unknown `posted_date` / `deadline` / `location`, rank fields only when scored. Verified: `csv.DictReader`, `job_key.py --audit` (exit 0) and `rank_state.py candidates` read the output.
- Decide in Step 7: how the app sets `fit` (high / medium / low), and whether `rank_verdict` on a gate FAIL is `band(score)` (repo `rank_state.py`) or `Poor Fit` (§5 Step 7).
- 2026-09-27, Step 3: all four Greenhouse hosts (`boards.`, `job-boards.`, `boards.eu.`, `job-boards.eu.greenhouse.io`) use `boards-api.greenhouse.io`; `boards-api.eu.greenhouse.io` does not resolve. Lever single-posting endpoint is documented in the README. EU Lever (`jobs.eu.lever.co`) is not detected yet and falls back to `.html`.
- `FetchedPosting.company` = the ATS board token: `/scrape` stored these jobs as `stratum3`, `Sandboxly`, `Variantly`, so `JobKey` matches. `postedAt`: Greenhouse `first_published` (never `updated_at`), Lever `createdAt`, Ashby `publishedAt`. `plainText` starts with the title and ATS facts (Location, Workplace, Commitment / Employment, Compensation).
- Network tests: `JOBSCOUT_GREENHOUSE_BOARD=<token> JOBSCOUT_LEVER_SITE=<site> JOBSCOUT_ASHBY_BOARD=<board> swift test --filter LiveATSTests`. Each test is skipped without its variable (2026-10-11; before: `JOBSCOUT_NETWORK_TESTS=1` with hard-coded boards).
- 2026-09-27, Step 4: no SwiftSoup. `NSAttributedString` HTML import lives in UIKit / AppKit, so rule 3 forbids it in Core. The standard-library `HTMLText` passes all three page fixtures (LinkedIn, Northvale careers, hh.ru) in 0.41 s together (debug). It drops `script`, `style`, `head`, `template` (hh.ru keeps 500 KB of JSON there), `nav`, `footer`.
- LinkedIn guest pages: body = `div.show-more-less-html__markup` + `ul.description__job-criteria-list` (1 654 → about 510 words; keeps "Employment type"). Pages that render the job with JavaScript give almost no text (one company careers page: 314 chars; its JSON-LD holds only a 328-char summary): share the posting text instead.
- `Truncator` keeps paragraph 1 (title + ATS facts) and the requirements section, then fills the budget in document order up to the first paragraph that does not fit.
- 2026-09-27, Step 5: `JobPosting.eligibilityQuote` is an addition to §4, so an eligibility FAIL can quote the posting. Remote policy `.unspecified` → location FLAG ("unverified"); hybrid elsewhere is treated like on-site. Not gates in V1: the 35 USD/h rate floor (FitEvaluation has no slot; the profile tells the scorer) and "frequent travel" (no extracted field).
- Step 6: `LLMClient.tokenCount` is `async throws` like the SDK. Budget = context − (instructions + schema + fixed prompt) − 600; `GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 600)`; one retry at 75 % on `contextSizeExceeded`. The posting goes in the prompt, never the instructions. Core resources use `.process`: a top-level `Resources/` folder breaks code signing of the flat iOS resource bundle.
- Grounding (`Core/Rubric/Grounding.swift`): the first device run invented `.sponsors`, `.remote`, `.fullTime` and "not specified" for a posting that states none of them, and a later run listed Python as a required language (false language FAIL). `JobPosting.grounded(in:)` keeps a claim only when the text supports it, quotes the eligibility sentence from the text, and drops programming languages. It never upgrades a field: a stance the model misses stays missed (halcyon: "unable to provide visa sponsorship" came back as silent).
- The Step 6 device test accepts `.remote` or `.unspecified` for job_posting.md: the text never says remote.
- Step 7 decisions: rounding is half up in integer hundredths (= rank_state.py `int(total + 0.5)`). Export: `rank_verdict` = band of the score, eligibility FAIL folds into `location_verdict` FAIL (rank_state.py convention); `fit` = high for Strong/Good, medium for Moderate, low otherwise or on any FAIL. The app screen shows Poor Fit on a FAIL (§5).
- Step 7 eval (iOS 27 simulator, host model, contextSize 4096, 10 fixtures in `Tests/Fixtures/Eval/`): sampled run 8/10; greedy run 6/10 (a Python "language" caused a false FAIL); after the language fix, greedy 7/10 on two runs. Exact band 4/10. The model compresses scores into two patterns (90/80/70/x and 80/60/60/60): mean overall 75.4 vs 67.1 from /rank; Moderate/Weak over-scored by +7 to +24 (three of four by +21 to +24), Strong under-scored by 1–5. Greedy stays for reproducibility; calibration is open work. Details and raw outputs: `docs/MODEL_BEHAVIOR.md`.
- Review fixes (2026-09-27): grounding removes only the permissive `.sponsors` claim and checks every sponsorship sentence for a negation; restrictive stances and paraphrased places stay. Location passes when any listed place is a candidate region; "anywhere in X" names X. Blank rows are ignored; "German is a plus" is a FLAG. CSV quotes CRLF; notes use `singleLine`. One-requirement-per-paragraph sections survive truncation. Non-UTF-8 pages (PDF) are rejected.
- Step 8: `IncomingItem` and `TrackedJob` share the App Group SwiftData store (`SharedStore`). The extension does not open the app (iOS share extensions cannot). Safari on iOS 27 shares `http://` for https pages; the ATS path does not care.
- Step 9/10: `ParseModel` (Core, `@Observable`) is the view model: idle → fetching → extracting → scoring → done | failed(reason). If a link fails to fetch and the share carried text, the text is parsed. Dedup goes through `SharedStore.add` (`@Attribute(.unique)` alone would upsert over the existing row). Without the App Group the app falls back to a local store and says so in Settings. Tracker notes stay on one line (/outcome edits rows line by line). Export: CSV with header + seen_jobs JSON via ShareLink; append with `tail -n +2 job_search_tracker_export.csv >> job_search_tracker.csv`.
- §6 "`git grep -i "sk-ant"` returns nothing" will match its own line in this file once committed; a tree grep finds no other hit.
- XcodeBuildMCP checked after the session restart: `session_show_defaults` reads `.xcodebuildmcp/config.yaml`, `test_sim` runs the suite. `list_devices` shows the CoreDevice id for the device; `xcodebuild` uses the UDID in the config.
- 2026-09-27, product: the user wants JobScout as a product. After an LLM Council session (`docs/council-transcript-2026-09-27.md`) the accepted positioning is: hook = instant verdict with quoted proof, body = tracker, pricing note = free/private, one Siri intent; CV/cover letters out of V1. Plan v2: `docs/PRODUCT_PLAN.md`. Next build: remove the hard-coded profile — `CandidateProfile` + multiple CVs (Phase 1). §1 scope and §9 stay in force until Phase 1 starts.
- 2026-09-27, eval research (docs/MODEL_BEHAVIOR.md §7, docs/EVALS.md): the model no longer scores. `LLMClient.score` is replaced by `digest(postingText:) -> PostingDigest` (posting only, no profile; `prompts/digest.md`), and `FitRubric` computes T/E/B/C, strengths and gaps in Swift. Reason: 4 model-scoring variants (0-100, anchored levels, digest + levels, few-shot) scored 6–7/10 with bias +8 to +17; digest + FitRubric scored 10/10 on dev and 23/24 on the holdout. Same 2 calls per posting.
- `PromptBudget.profile`, `PromptRenderer.score` and the Settings "Profile" row are gone. `score.md`, `rubric_compact.md`, `profile_*.md`, `Golden/score_prompt.txt` and `LLM/tbd_scores.json` were unused; deleted on 2026-10-11 (issue #3).
- Holdout set: `Tests/Fixtures/Eval/Holdout/` (25 English postings with a `/rank` score). Tune FitRubric tables and prompts on dev only; score the holdout once per frozen change.
- 2026-09-27, gate injection eval: the model missed 8 of 9 inserted eligibility sentences. `Grounding.statedRestriction` now upgrades `visaSponsorship` from a citizenship / clearance / work-authorization sentence (never lowers a stricter stance; skips equal-opportunity text). This reverses the Step 6 "never upgrades a field" note for restrictions only. `FoundationModelsClient` retries once without 1-3 word paragraphs after `unsupportedLanguageOrLocale` (threadly).
- 2026-10-12, CI (#4): `.github/workflows/ci.yml` runs on push and pull_request (macos-26, newest Xcode, `swift test`, then `scripts/publish-guard.sh`). The guard uses generic regexes only (`scripts/publish-guard.patterns`: home paths, `8-16` hex device UDIDs, a hard-coded 10-char `DEVELOPMENT_TEAM`, emails outside an allowlist of example and fake fixture domains); the 40-hex old-UDID shape is left out because it matches git SHAs and Cloudflare email hex in tracked docs and fixtures. Literal names stay local: install the pre-push hook once with `ln -s ../../scripts/pre-push .git/hooks/pre-push`; it blocks a push when a tracked file or path contains a line from the gitignored `.private/forbidden.txt`. The macos-26 runner's newest Xcode is 26.6 (no Xcode 27 / iOS 27 SDK yet); Core still builds and all CoreTests pass there. The Xcode 26.6 type checker timed out on one long expression in `FitRubric.scores`, so it is split in two lines: if CI shows "unable to type-check", split the expression; do not pin a Swift version.

---

## Agent skills

### Issue tracker

Issues live in GitHub Issues on `ayyyvar/jobscout` (use the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the repo root (created lazily). See `docs/agents/domain.md`.
