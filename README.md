# job-to-offer

[![CI](https://github.com/ayyyvar/job-to-offer/actions/workflows/ci.yml/badge.svg)](https://github.com/ayyyvar/job-to-offer/actions/workflows/ci.yml)

job-to-offer is an iOS 27 app: share a job posting into it, and Apple's on-device Foundation Models extract the fields.
Deterministic Swift gates then decide eligibility, language and location, and every FAIL or FLAG quotes the posting; a fit estimate and strengths / gaps follow.
A tracker keeps the jobs and exports CSV and JSON. Free and private: no account, no server, nothing leaves the phone except the fetch of the posting you share.

## Screenshots

| Inbox | Job detail | Tracker | Settings |
|---|---|---|---|
| ![Inbox](docs/screenshots/inbox.png) | ![Job detail](docs/screenshots/detail.png) | ![Tracker](docs/screenshots/tracker.png) | ![Settings](docs/screenshots/settings.png) |

## How it works

```mermaid
flowchart LR
    A[Share sheet<br>URL or text] --> B{Fetch}
    B -->|Greenhouse / Lever / Ashby| C[ATS JSON]
    B -->|any other URL| D[HTML to text]
    C --> E[Extract<br>@Generable JobPosting]
    D --> E
    E --> F[Grounding<br>check claims against text]
    F --> G[Gates in Swift<br>eligibility / language / location]
    G --> H[Digest<br>model describes the posting]
    H --> I[FitRubric in Swift<br>score, band, strengths, gaps]
    I --> J[Tracker<br>CSV / JSON export]
```

1. **Fetch.** ATS links go to the public Greenhouse, Lever or Ashby JSON APIs. Other URLs are converted from HTML to plain text with the standard library (no dependencies).
2. **Extract.** One `LanguageModelSession` call fills a `@Generable JobPosting`: title, remote policy, location requirement, visa stance, required languages, stack.
3. **Grounding.** Swift keeps a model claim only when the posting text supports it, and quotes the sentence behind an eligibility verdict.
4. **Gates.** Pure Swift decides PASS / FAIL / FLAG for eligibility, language and location against the user's profile.
5. **Digest + FitRubric.** A second call describes the posting (role focus, LLM work, must-haves). Swift tables turn that into four dimension scores, a weighted overall score and a band.

The model sits behind the `LLMClient` protocol. `FoundationModelsClient` is the only file that imports `FoundationModels`; the `Core` package compiles for macOS and iOS with no UI imports.

## Why the model extracts and Swift decides

| Approach | Dev within one band | Bias |
|---|---|---|
| Model scores 0-100 per dimension, plus 3 prompt variants (anchored levels, digest + levels, few-shot) | 6–7 / 10 | +8 to +17 |
| Model writes a digest, Swift `FitRubric` scores | 10 / 10 dev, 23 / 24 holdout | +2.9 |

- **The model flatters the candidate.** In one variant it marked 56 of 60 requirement checks as "has".
- **Grounding stops invented claims.** An early run returned "sponsors visas", "remote" and "full-time" for a posting that states none of them.
- **A prompt change never changes a gate verdict.** The gates read typed fields and the posting text; no prompt decides PASS or FAIL.

The full record is in [`docs/MODEL_BEHAVIOR.md`](docs/MODEL_BEHAVIOR.md) §7.

## Eval results

Runner: `DeviceTests` on the iOS 27 simulator (host model, greedy, context 4096), 2026-10-11.
Reference: a score from a stronger model (Claude) with the full rubric, not ground truth. Tolerance: the produced band equals the reference band or an adjacent one.

| Set | Postings | Within one band | Exact band | MAE | Bias |
|---|---|---|---|---|---|
| Dev (tables tuned here) | 10 | 9 / 10 (1 blocked by the guardrail) | 6 | 6.0 | +2.4 |
| Holdout | 25 | 25 / 25 | 13 | 7.9 | +4.4 |
| Holdout2 | 18 | 18 / 18 | 10 | 6.2 | +0.1 |
| Low (weak-fit postings) | 17 | 13 / 17 | 7 | 17.9 | +14.8 |

| Gate check | Result |
|---|---|
| Real postings that must not get a location PASS | 16 / 16 not PASS |
| Gate injection: one restriction sentence inserted per case | 17 / 17 |

Known limits:

- **Low postings are over-scored** by about 15 points on average. Calibration is open work.
- **Apple's safety guardrail blocks some ordinary postings.** One dev posting fails with `guardrailViolation`; the client retries once without visa lines and short paragraphs. The guardrail is not deterministic.
- **The context is 4096 tokens** on the tested iPhone and simulator. Long postings are truncated; the requirements section is kept first.
- **English only.** The on-device model does not support every language.

Eval method and catalog: [`docs/EVALS.md`](docs/EVALS.md).

## Testing

```sh
swift test
```

199 Swift Testing tests in `CoreTests` run on any Mac with no Apple Intelligence: the model is replaced by `FakeLLMClient` behind `LLMClient`.

Device tests (real model, eval sets, gate injection) need the iOS 27 simulator on a Mac with Apple Intelligence on:

```sh
xcodebuild test -workspace job-to-offer.xcworkspace -scheme job-to-offer \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
```

Device tests skip with a printed reason when the model is unavailable. Add `-only-testing:DeviceTests/EvalTests` for the eval tables (about 35 s per posting).

Live ATS calls are off by default. Each test reads its board from the environment:

```sh
JOB_TO_OFFER_GREENHOUSE_BOARD=<token> JOB_TO_OFFER_LEVER_SITE=<site> JOB_TO_OFFER_ASHBY_BOARD=<board> \
  swift test --filter LiveATSTests
```

## Build

Requirements: Xcode with the iOS 27 SDK, [XcodeGen](https://github.com/yonaskolb/XcodeGen), and an Apple Intelligence device (iPhone 15 Pro or later) to parse postings.

```sh
xcodegen generate
open job-to-offer.xcworkspace
```

- **Open the workspace, not the folder.** The folder has `Package.swift` at its root, so Xcode opens it as the `Core` package with no app target.
- **Signing.** `Signing.xcconfig` holds defaults (`com.example.job-to-offer`, no team) that build for the simulator. For a device, create a gitignored `Local.xcconfig` next to it with `APP_BUNDLE_ID`, `APP_GROUP_ID` and `DEVELOPMENT_TEAM`, then run `xcodegen generate` again. Do not set signing in the Xcode UI: regeneration resets it.

## Project status

V1 (share, parse, gates, fit estimate, tracker, export) works on an iPhone with iOS 27. Profile and resume import replace the hard-coded candidate. App Store release is planned; see [`docs/PRODUCT_PLAN.md`](docs/PRODUCT_PLAN.md).

## AI-assisted development

The app was built test-first with Claude Code. [`CLAUDE.md`](CLAUDE.md) holds the spec the agent worked from and the decisions log: every design change, the measurement that caused it, and the eval numbers before and after.

## License

MIT. See [`LICENSE`](LICENSE).
