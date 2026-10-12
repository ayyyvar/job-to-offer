# JobScout as a product — plan (v2, 2026-09-27)

**TL;DR:** The product is the instant verdict with proof: "know in 10 seconds if you waste this application — including whether you can legally take the job." The tracker retains users. Free / on-device is the pricing note. Siri is one intent. CV / cover-letter generation is out of V1.

Status: accepted by the user on 2026-09-27 after an LLM Council session. Transcript: `docs/council-transcript-2026-09-27.md`. v1 of this plan (eligibility-first, 10 interviews before code) is superseded.

---

## 1. Positioning

| Layer | What | Why |
|---|---|---|
| **Hook** | Share a posting → verdict in ~10 seconds: can you take this job (visa / location / language), fit estimate, strengths / gaps | The deterministic gates are the only durable edge. Siri missed location in 3 of 3 tested postings; the gates flagged all 3 |
| **Proof** | Every FAIL / FLAG shows the quoted sentence from the posting. Uncertain cases say "not sure — check yourself" | The cost of a wrong verdict is a lost job (false FAIL) or a wasted week (false PASS). Trust is earned on the first 3 jobs |
| **Body** | Tracker: statuses, follow-ups, export | Retention between verdicts. What keeps the app installed |
| **Pricing note** | Free to run, no server, no account, data on the phone. "No $29/mo" | Zero marginal cost enables the price; it is not the headline |
| **Channel** | One Siri App Intent ("check this job") + share sheet + CIS / relocation communities | Users search "job tracker", not "on-device AI". The builder lives in the target communities |

Cut from V1: CV / cover-letter generation (3B model unproven, PCC entitlement gated, ChatGPT is free and better), fit score as a headline (over-scores weak jobs by +21–24; demote to "estimate"), rule-pack marketplace, B2B API (kept as a fallback if consumer retention fails).

No user-facing words: token, PCC, on-device model, CSV. Say: free, private, works offline, export.

---

## 2. Evidence base

- Siri test (3 postings, 4 answers, 2026-09-27): Siri reads the screen, not the page; missed location / visa in 3 of 3; called a Weak-fit job "strong candidate". Details in `council-transcript-2026-09-27.md` and the chat log.
- Own eval (10 postings): 7 of 10 within one band, Moderate / Weak over-scored by +21–24. `docs/MODEL_BEHAVIOR.md`.
- Greenhouse `?questions=true` returns application-form questions (verified live on QuantaOps: "Do you currently live legally in Europe?"). The gates cannot see this today.
- Market: Teal / Huntr ~$29/mo (server); Jobright H-1B filter (US-only); LinkedIn Premium Job Match ~$240/yr. Prices from third-party reviews, not verified with vendors.

---

## 3. Build phases (test-first, per CLAUDE.md §3)

### Phase 1 — Profile + TestFlight (the onboarding cliff)

The council named this the biggest unscoped build. The gates work only against a profile, and today it is hard-coded (languages in `Core/Rubric/Gates.swift:38`, region in `Core/Rubric/Gates.swift:74`; the CV lives in `Core/Resources/profile_*.md`).

- **Buy the Apple Developer account ($99).** Personal Team cannot ship TestFlight. Blocker for everything.
- **`CandidateProfile` (SwiftData):** citizenships, work authorizations, home city + country + time zone, languages with levels, relocation stance, employment types, rate floor. The user types the constraints; they stay deterministic inputs to the gates.
- **Multiple CVs (user decision 2026-09-27):** a `Resume` entity, several per profile (e.g. AI-engineer CV, backend CV). Import: PDF text via PDFKit or pasted text. The model extracts skills / experience into a rendered profile; the user edits and confirms. Per-check resume selection, with a default. Scoring runs against the chosen resume; gates run against the shared constraints.
- **Gates read `CandidateProfile`.** Regression test: the current candidate as a fixture profile reproduces every existing gate-table verdict.
- **Generic rubric:** `rubric_compact.md` keeps bands and dimension definitions; skill lists and goals come from the selected resume. Goldens change in a `golden:` commit.
- **Remove the personal data from the binary:** `profile_compact.md` / `profile_full.md` move to `Tests/Fixtures/`.
- **Export:** tracker CSV stays; the `seen_jobs.json` export moves behind a setting (only the builder's repo reads it).
- Done when: a stranger installs from TestFlight, fills the profile, imports a CV, shares a posting, gets a verdict.

### Phase 2 — Ten testers

- 10 testers from cross-border job-seeker / CIS relocation communities.
- Expect breakage on real postings (LinkedIn JS pages already fail; see CLAUDE.md §11). Log every fetch / extraction failure with the URL pattern.
- Add the Greenhouse `?questions=true` check: deterministic scan of question labels ("live legally", "authorized to work", "sponsorship", "citizen", "reside") → FLAG with the quoted question. The client uses only `?content=true` today (`Core/Fetch/GreenhouseClient.swift:23`).
- Decide: remote with no country list → FLAG "unverified" (align with /rank; today it is PASS — the Kaplo case).
- Verdict UI per council: quote as proof on every FAIL / FLAG; "not sure" state when the extraction confidence is low; fit score labeled "estimate", editable.
- Measure: checks per user per week, share of verdicts users agree with, week-2 retention, fetch failure rate by source.

### Phase 3 — One Siri intent

- `TrackedJob` as an `AppEntity`; one intent: "check this job" → PASS / FAIL / FLAG + band in the Siri answer. Nothing more in V1.
- View annotation so Siri resolves "this job" on screen.
- Tests: `perform()` with `FakeLLMClient`.

### Phase 4 — Score quality (only after retention exists)

- PCC (`PrivateCloudComputeLanguageModel`, 32K context, per-user daily quota, managed entitlement — apply early, approval time unknown) for scoring long postings; on-device fallback offline / over quota; quota status in the UI.
- Recalibration flywheel: every tracked outcome is a labeled example. Grow `Tests/Fixtures/Eval/` to 30 postings across ≥3 profiles. Targets: ≥9 of 10 within one band; Weak / Moderate bias ≤ +10.
- CV / cover letters: reconsider only here, via PCC, behind a flag, never promised in marketing.

### Kill / pivot rule

If after Phase 2 the testers do not return in week 2 and do not agree with the verdicts, stop the consumer push. Fallbacks, in order: (1) B2B — the rule engine + profile as an API for job boards / relocation services; (2) personal tool + portfolio piece. Same codebase either way.

---

## 4. Risks

| Risk | Mitigation |
|---|---|
| Wrong verdict destroys trust | Quote as proof; "not sure" state; gates never upgrade a claim (`Core/Rubric/Grounding.swift`) |
| Job search is episodic (churn in 8–12 weeks) | Tracker + follow-ups as retention; price accordingly (one-time / cheap annual); measure before pricing |
| Market too small (iPhone 15 Pro+, English postings, cross-border) | Phase 2 measures demand before further build; kill rule above |
| Apple ships eligibility checks in Siri | The moat is profile + gates + tracker; the Siri intent makes JobScout the tool Siri calls |
| PCC entitlement denied / delayed | V1 does not depend on PCC; apply early, treat as upside |
| LinkedIn fetch breaks / ToS | Share text fallback exists; ToS review before public launch |
| Day-job IP clauses | Check the employment contract before a public launch |

---

## 5. Sources

- Council transcript: `docs/council-transcript-2026-09-27.md`
- Model behavior: `docs/MODEL_BEHAVIOR.md`
- Apple PCC: https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute (read 2026-09-27)
- WWDC26 240 App Schemas: https://developer.apple.com/videos/play/wwdc2026/240/
- MacRumors, Siri in iOS 27: https://www.macrumors.com/guide/ios-27-siri/
- Greenhouse questions API, checked live 2026-09-27: https://boards-api.greenhouse.io/v1/boards/quantaops/jobs/4986807101?questions=true
- Third-party reviews: Jobright (wobo.ai), LinkedIn Premium (resumehog.com), trackers (prentus.com)
