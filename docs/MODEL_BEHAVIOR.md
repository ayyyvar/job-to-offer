# On-device model behavior (observed 2026-09-27)

**TL;DR:** the model fills every field, even when the posting states nothing. Asked to rate fit, it rates almost every posting "good" or better. Since 2026-09-27 the model only describes the posting (`PostingDigest`), and Swift computes all four scores (§7). Swift code must still check each claim that a gate uses.

All data below comes from runs in this repo. Nothing is from Apple documentation. From the device (iPhone 16e) there is only one Settings screenshot so far (§1).

---

## 1. Setup

| Item | Value |
|---|---|
| Runtime | iOS 27.0 simulator (iPhone 18 Pro). It uses the host Mac model (macOS 26.6.2). |
| `contextSize` | 4096 tokens on the simulator, on the host and on the iPhone 16e (iOS 27.0). WWDC26 talks about 8192; this device reports 4096. |
| iPhone 16e, one parse | Last prompt 2409 tokens, not truncated, `profile_compact` (Settings screenshot, 2026-09-27). |
| Languages | da, de, en, en-AU, en-GB, en-IN, es, es-419, es-US, fr, fr-CA, it, ja, ko, nb, nl, pt, pt-PT, sv, tr, vi, zh, zh-HK, zh-TW. No Russian. |
| First boot | `modelNotReady` at 16:18 and 16:20, `available` at 17:02. |
| Errors | No `LanguageModelError` in 3 eval runs, 3 extraction runs and 1 end-to-end run. |

The code under test:
- Prompts: `Core/Resources/prompts/extract.md`, `score.md`, `rubric_compact.md`, `profile_compact.md` (4096 context).
- Client: `JobScoutApp/LLM/FoundationModelsClient.swift`.
- Eval set: `Tests/Fixtures/Eval/manifest_2026-09-27.json`, 10 postings with the band from `/rank`.

---

## 2. Tokenizer

Counts come from `SystemLanguageModel.default.tokenCount(for:)` on the host. The API needs macOS 26.4 or later.

| Text | `Prompt(text)` | `Instructions(text)` |
|---|---|---|
| `profile_full.md` | 845 | 852 |
| `profile_compact.md` | 432 | 439 |
| `rubric_compact.md` | 669 | 676 |

- **Fixed cost:** about 8 tokens per `Prompt` and 15 per `Instructions`. A 29-character string gave 16 and 23.
- **Number ranges cost more:** "80-100" costs about 10 tokens more per line than "80+".

---

## 3. Extraction (`JobPosting`)

**Test posting:** `Tests/Fixtures/Eval/tbd_senior-ai-engineer_2026-09-25.md`. It states no remote policy, visa rule, employment type, pay or deadline. The word "remote" occurs 0 times.

### 3.1 Raw model output, before the Swift checks

| Field | Truth | Run 1 (sampling) | Run 2 (greedy) |
|---|---|---|---|
| company | not stated ("[Company TBD]") | "Company TBD" | "Company TBD" |
| location | not stated | "Remote" | "Remote" |
| remotePolicy | not stated | `remote` | `remote` |
| employmentType | not stated | `fullTime` | `fullTime` |
| locationRequirement | none | ["Remote"] | [] |
| visaSponsorship | not stated | **`sponsors`** | **`sponsors`** |
| eligibilityQuote | none | "3+ years of experience as a Senior Software Engineer…" | same |
| requiredLanguages | English, B2 or higher | English (B2) | English (B2 level or higher), **Python** ("especially web frameworks like FastAPI") |
| stack | about 10 named tools | python, fastapi, nlp | python, nlp |
| minYearsExperience | 3 | 3 | 3 |
| compensation | none | "not specified" | "salary" |
| deadline | none | "not specified" | "2026-09-25" (the archive date in the file header) |

### 3.2 Patterns

1. **It never leaves a field empty.** Enum fields get a value instead of `unspecified` or `silent`. The prompt tells it not to guess.
2. **Its default visa stance is the permissive one.** It returned `sponsors` for a posting with no word about visas. That is a false PASS.
3. **The quote is not tied to the stance.** `eligibilityQuote` holds a sentence about experience.
4. **Empty strings become placeholder words:** "not specified", "salary".
5. **It takes any date as the deadline.** The date came from the file header, not from the posting.
6. **It lists programming languages as human languages.** Python in `requiredLanguages` made the language gate FAIL a Strong Fit posting.
7. **Stack extraction is incomplete.** It named 2–3 of about 10 tools. It missed rag, openai, anthropic, bedrock, langgraph, llamaindex, streamlit and gradio.
8. **It misses restrictive statements.** The halcyon posting says "We are unable to provide visa sponsorship". Eligibility came back PASS.
9. **The title is reliable.** "Senior AI Engineer" and "Senior Applied AI Engineer" came back right in every run.

---

## 4. Scoring (`DimensionScores`) — the old model scoring

This section describes the model-scored pipeline before 2026-09-27. §7 replaces it.

### 4.1 Sampling makes scores unstable

| Run | Posting | T/E/B/C | Overall |
|---|---|---|---|
| Eval, default sampling | sandboxly | 80/75/70/70 | 74 |
| End-to-end in the app, default sampling | sandboxly (same posting) | 100/100/100/100 | 100 |
| Eval, greedy (two runs) | sandboxly | 90/80/70/80 | 82 |

Bullets from the 100/100/100/100 run:
- **Strengths:** "Collaborative and deeply collaborative"; "Strong verbal and written English communication skills are required" (this is a requirement, not a strength).
- **Gaps:** "Experience in production LLM agents". The profile states production LLM work.

### 4.2 Greedy output has two patterns

Final eval, greedy, after the language fix. The result was identical on two runs.

| Fixture | /rank band | /rank score | App overall | Diff | T/E/B/C | Within 1 band |
|---|---|---|---|---|---|---|
| tbd_senior-ai-engineer | Strong | 80 | 79 | −1 | 90/80/70/70 | yes |
| sandboxly | Strong | 85 | 82 | −3 | 90/80/70/80 | yes |
| kaplo | Strong | 84 | 79 | −5 | 90/80/70/70 | yes |
| quantaops | Good | 71 | 82 | +11 | 90/80/70/80 | yes |
| nxt-partner | Good | 70 | 66 | −4 | 80/60/60/60 | yes |
| lumisoft | Good | 69 | 79 | +10 | 90/80/70/70 | yes |
| tidewell python-developer | Moderate | 59 | 66 | +7 | 80/60/60/60 | yes |
| variantly | Moderate | 58 | 79 | +21 | 90/80/70/70 | no |
| halcyon | Moderate | 53 | 76 | +23 | 90/80/70/60 | no |
| tidewell data-science-credit-risk | Weak | 42 | 66 | +24 | 80/60/60/60 | no |

- **Two patterns cover all 10 postings:** 90/80/70/{60, 70, 80} and 80/60/60/60.
- **The range is compressed:** app 66–82, /rank 42–85.
- **The bias is positive:** mean 75.4 against 67.1.
- **Low bands are scored too high:** Moderate and Weak by +7 to +24; three of the four by +21 to +24.
- **High bands are scored a little low:** Strong by −1 to −5.
- **Exact band:** 4 of 10. The one-band tolerance hides most of the error.

### 4.3 Hit rate by run

| Run | Within one band |
|---|---|
| Default sampling | 8 / 10 |
| Greedy, before the language fix | 6 / 10 (a false language FAIL forced Poor on tbd) |
| Greedy, after the fix (two runs) | 7 / 10 |

The 8/10 does not mean that sampling is better. Sampling moved the same posting from 74 to 100.

---

## 5. Speed

- **One model call on the simulator takes about 30 s.** The sampled eval made 20 calls in 616 s.
- **A full suite with eval takes 745 s.**
- **The phone is not timed yet.** All four share paths worked on it (user report, 2026-09-27).

---

## 6. What the code does about it

| Behavior | Countermeasure | Where |
|---|---|---|
| Unstable output | `samplingMode: .greedy` | `FoundationModelsClient.options` |
| Output longer than the budget | `maximumResponseTokens: 600`, the same value as `PromptBudget.outputReserve` | `FoundationModelsClient.options` |
| Invented `sponsors` | Kept only if a sentence mentions sponsorship, visa or relocation. A negated sentence ("not available", "can't") → `authorizationRequired`. | `Core/Rubric/Grounding.swift` |
| Invented quote | The quote comes from the posting text. The model's words are kept only if they occur in the text. | `Grounding.swift` |
| Missed or paraphrased restriction | Restrictive stances and places are never removed. A wrong FAIL is visible and editable; a wrong PASS is silent. | `Grounding.swift` |
| Invented remote or full-time | Kept only if the text contains a word for it. | `Grounding.swift` |
| Placeholder pay or deadline | Pay needs a digit; the deadline must be `YYYY-MM-DD`. | `Grounding.swift` |
| Python as a language | Programming languages and `stack` items are removed from `requiredLanguages`. | `Grounding.swift` |
| Flattering fit ratings | The model never sees the profile. It describes the posting; Swift computes T/E/B/C, strengths and gaps (§7). | `Core/Rubric/FitRubric.swift` |
| Tool names as languages ("Azure DevOps") | Names in the FitRubric skill areas are removed from `requiredLanguages`. | `Grounding.swift` |
| Overall score and band | Computed by Swift, never by the model. | `Core/Rubric/Scoring.swift` |
| Everything else | The screen marks all fields as AI-generated and lets the user edit them. Gates run again after each edit. | `JobScoutApp/JobDetailView.swift` |

**Limit (until 2026-09-27):** grounding never added a restriction, so a missed "citizens only" passed. `Grounding.statedRestriction` now adds one from a sentence in the text (§7.4). A restriction worded outside its patterns still passes silently.

---

## 7. Scoring experiment: the model describes, Swift scores (2026-09-27)

**Result:** model scoring failed in 4 variants. A digest call plus Swift tables won on dev and on an unseen holdout set. It uses the same 2 model calls per posting as before.

### 7.1 Setup

- **Runner:** a host command-line harness with the same `Core` and `FoundationModelsClient` as the app. It uses the macOS 26.6.2 model (context 4096, greedy). The baseline matched the simulator run in §4.2 exactly.
- **Dev set:** the 10 Step 7 fixtures. The FitRubric tables were set on dev.
- **Holdout set:** 25 other English postings with a `/rank` score (`Tests/Fixtures/Eval/Holdout/`). Each frozen variant was scored once. LinkedIn served 4 title lines in Polish; the harness replaced them with the English template (noted in the manifest).
- **Reference:** the `/rank` score (Claude with the full rubric). It is a stronger model's judgment, not ground truth.

### 7.2 Variants on dev

| Variant | Calls | Within 1 | Exact | MAE | Bias | Spearman | Distinct T/E/B/C |
|---|---|---|---|---|---|---|---|
| Baseline: model gives 0-100 per dimension | 2 | 7/10 | 4 | 10.9 | +8.3 | 0.65 | 4 |
| A: 5 anchored levels, requirement check before the levels | 2 | 6/10 | 3 | 16.5 | +16.5 | 0.56 | 4 |
| B: digest call, then model levels on the digest | 3 | 6/10 | 3 | 15.8 | +15.8 | 0.80 | 3 |
| C: B plus 3 synthetic few-shot anchors | 3 | 6/10 | 4 | 15.0 | +14.8 | 0.68 | 3 |
| **D: digest call, FitRubric in Swift (shipped)** | 2 | **10/10** | **6** | **6.1** | **+2.9** | **0.84** | **10** |

- **The model flatters the candidate.** In A it marked 56 of 60 requirement checks "has". In B and C it gave one level to all four dimensions on 9 of 10 postings.
- **Few-shot anchors do not help.** In C, the credit-risk posting is close to one anchor ("technical partial, career weak"). It still got "good" on all four dimensions.
- **The model classifies the posting well.** `roleFocus` put the backend, ML-modelling and LLM postings into the expected groups on dev.

### 7.3 Holdout (25 postings, scored once per frozen variant)

| Variant | Within 1 | Exact | MAE | Bias | Spearman | Distinct T/E/B/C | Errors |
|---|---|---|---|---|---|---|---|
| Baseline: model gives 0-100 | 14/25 | 5 | 16.0 | +13.9 | 0.44 | 8 | 1 |
| D, Python prototype of the tables | 23/24 | 14 | 8.2 | +2.7 | 0.84 | – | 1 |
| D2: requirements first, new `llmWork` definition | 22/24 | 9 | 9.8 | +5.9 | 0.72 | – | 1 |
| **D in Swift (shipped), with the "Azure DevOps" fix** | **24/25** | **14** | **8.3** | **+3.8** | **0.86** | **20** | 1 |
| D after Phase 1 (`CandidateProfile.fixture`, 2026-09-28) | 24/25 | 14 | 8.3 | +3.8 | 0.86 | 20 | 1 |

Phase 1 moved the lexicon into `CandidateProfile` / `SkillTiers`; with the fixture candidate the host numbers are identical on dev (10/10, exact 6, MAE 6.1) and holdout. The host error is threadly: the language retry fires only on iOS 27, where the framework throws `LanguageModelError`.

**iOS 27 simulator, `EvalTests` (2026-09-28), with the restriction rule and the language retry:**

| Set | Within 1 | Exact | MAE | Bias | Spearman | Failures |
|---|---|---|---|---|---|---|
| Dev | 9/10 | 6 | 6.0 | +2.4 | 0.89 | variantly: `guardrailViolation` |
| Holdout | 24/25 | 13 | 8.4 | +4.8 | 0.79 | zephyra: false language FAIL → Poor Fit |

- **The simulator is not the host.** It uses the macOS 26 host model through the iOS 27 framework. Its log shows 1 426 lines of "Encountered an unknown special token: com.apple.fm.language.safety_guardrail". On the host, variantly passes and zephyra gets a language PASS. The holdout case took 63 minutes on the simulator against 15 on the host.
- **zephyra's language FAIL comes from page chrome:** the Welcome to the Jungle language switcher "FrançaisEnglish (US)English (UK)". Proposed fix: drop a non-candidate language whose name does not occur in the text. Not built yet: Phase 1 work is changing `Grounding.swift`.
- **threadly parses** after the retry without short paragraphs: Good Fit 64 against `/rank` 59.

- **All five Weak postings were 63–66 in the baseline.** D gives them 44–58; the data-engineering and analytics roles now land in Weak or Moderate.
- **Remaining misses are `llmWork` recall:** stayloft (79) and codemill (76) are Strong in `/rank` and Good in D, because the digest said `none` or `part`.

- **One error in every variant:** threadly throws `unsupportedLanguageOrLocale` on English text. The trigger is the two-word paragraph "Threadly Technologies" (the real company name is a Polish word; the anonymized fixture says "Threadly"). Merging it into the next line did not help. Without the 1–3 word paragraphs the posting parsed: Good Fit 64 against `/rank` 59. The client now retries that way after this error.
- **Property order did not help.** D2 lists the requirements before `roleFocus` and `llmWork`, and it rewrites the `llmWork` definition. It pushed nimbara, fortivo, lattice-motion and zephyra to `llmApplications/core`. The two changes were tested together, so their effects are not separated.
- **Baseline noise:** the baseline gave the same threadly posting 56, 72 or 79, depending on which page chrome stayed in the text.

### 7.3a More postings from `job_scraper/` (2026-09-28)

Source: the 53 remaining `/rank`-scored entries of `seen_jobs.json`, fetched on 2026-09-28 with `PostingFetcher`, plus the "Skipped after detail fetch" tables of the `scrape_*.md` files.

| Pool | Count | Use |
|---|---|---|
| English text | 13 + 5 with Russian page chrome (hh.ru, getmatch) + stayloft (fetched 09-27) | **Holdout2** (`Tests/Fixtures/Eval/Holdout2/`, 18 postings; one more dropped: JS shell with phone numbers) |
| Russian text | 17 | out of V1; language-error check |
| Mixed | 2 | parsed, both within one band |
| Empty or short (Telegram posts, whatjobs, one JavaScript careers page) | 11 | not used; Telegram posts are 1–3 line Russian summaries |
| Not fetched | 5 | HTTP 403 (wellfound, himalayas), 999 (LinkedIn) |
| Skipped by `/scrape` for location, English, fetched | 16 of 54 rows (26 LinkedIn links not fetched: rate limit) | **GatesReal** (`Tests/Fixtures/Eval/GatesReal/`): combined location + eligibility must not be PASS |

**Holdout2 — postings nobody had scored before (host, current `Core`):**

| Variant | Within 1 | Exact | MAE | Bias | Spearman | Distinct T/E/B/C | Errors |
|---|---|---|---|---|---|---|---|
| Old: model gives 0-100 (same extraction, `score.md` + rubric + profile) | 13/17 | 4 | 13.7 | +12.6 | 0.48 | 5 | – |
| **D: digest + FitRubric** | **17/17** | **9** | **6.3** | **+0.2** | **0.62** | 15 | 1 |

- The error is staffora-solutions: `guardrailViolation` ("Detected content likely to be unsafe") on the host. Dropping 1–3 word paragraphs clears it (Strong Fit 79 against 77); stripping the Breezy `%…%` template tokens makes it fail the language check instead. The client's guardrail retry now drops visa lines and short paragraphs.
- Holdout2 has no Weak or Poor posting (4 Strong, 5 Good, 9 Moderate), and its `/rank` spread is narrow (SD 9.2), so Spearman is lower than on the first holdout.

**Rerun after the two fixes (host, 2026-09-28, stricter `sponsors` grounding + guardrail retry without short paragraphs):**

| Set | Within 1 | Exact | MAE | Bias | Spearman | Errors |
|---|---|---|---|---|---|---|
| Dev | 10/10 | 6 | 6.1 | +2.9 | 0.84 | 0 |
| Holdout | 24/25 | 14 | 8.3 | +3.8 | 0.86 | 1 (threadly, host only) |
| Holdout2 | **18/18** | 10 | 6.0 | +0.2 | 0.66 | 0 |
| GatesReal | 16/16 not PASS | – | – | – | – | 0 |

- **The guardrail is not deterministic.** staffora-solutions failed with `guardrailViolation` on the first host run and parsed on the rerun, with greedy sampling and no retry (the host never takes the retry path). Treat one guardrail failure as noise until it repeats.

**Russian postings (17):** all 17 end in `unsupportedLanguageOrLocale` within 0–4 s; no scores are made up. They are 17 of 87 ranked postings (20 %), all out of reach for V1.

**GatesReal (16 postings `/scrape` skipped for location):** 15 of 16 got FLAG. The miss was swatchwell: the model claimed `hybrid` + `sponsors`, and grounding kept `sponsors` because of "We sponsor multiple events throughout the year". Fixed: the permissive stance now needs visa, work permit, immigration, relocation or international applicants in the same sentence.

### 7.3b Low set: the bottom of the scale (2026-09-28)

**Source:** `job_scraper/rank_2026-09-28_low.md`: the user ran `/rank` on 25 `fit: low` postings (23 scored, 2 expired). Fetched 23; dropped 5 JavaScript shells and 1 Ukrainian-only posting. **17 postings** in `Tests/Fixtures/Eval/Low/`: 3 Poor, 6 Weak, 2 Moderate, 1 Strong by score, plus 5 language vetoes (Ukrainian or Polish required) with expected band Poor Fit. The 2 location vetoes (Quickwrite, Grafana) keep their score band: the app flags "remote only in country X" (CLAUDE.md §2).

| Variant | Within 1 | Exact | MAE | Bias | Spearman | Distinct T/E/B/C |
|---|---|---|---|---|---|---|
| Old: model gives 0-100 | 6/17 | 4 | 31.6 | +30.2 | −0.13 | 5 |
| **D: digest + FitRubric** | **13/17** | **7** | **18.1** | **+14.6** | **0.08** | 17 |

- **D still over-scores the bottom by about 15 points.** App overall 43–65 where `/rank` gives 17–58. Poor Fit (< 30) cannot come from the tables alone: all-weak technical is 39, and behavioral is 65 for most roles.
- **The classes are right; the tables are too flat.** backend/none gets experience 70 and career 45 whether the stack is Python or Go/C++/Rust (grafana: technical 49 with no strong skill, overall 55). Research pre-training (anchorline) is `mlModeling/core` and gets career 50.
- **Table variants (exact Python copy of `FitRubric`, 0 mismatches on 69 postings):**

| Variant | Dev MAE | Holdout MAE | Holdout2 MAE | Low MAE | Low Spearman |
|---|---|---|---|---|---|
| Shipped | 6.1 | 8.3 | 6.0 | 18.1 | 0.08 |
| Unknown requirement 0.4 (not 0.5) | 5.5 | 8.0 | 6.0 | 17.1 | 0.11 |
| Experience 50 when technical < 60 (same function, other stack) | 6.1 | 8.0 | 6.0 | 16.9 | 0.16 |
| Weak core stack caps technical at 45 | 6.1 | 8.1 | 5.9 | 17.4 | 0.09 |
| All three | 5.5 | 7.7 | 6.2 | 15.3 | 0.17 |

  Within-one-band stays 10/10, 24/24, 18/18 and 13/17 in every variant. The gains are small and were measured on every set we have, so there is no clean check. Not shipped.
- **Gates on Low:** language veto caught 4 of 5 (datavane's "Polish (Fluent)" was missed). Page chrome on arbeitnow ("- Applying for German Citizenship", "- Jobs with Visa Sponsorship") gave wraithwork a false citizenship FAIL and anchorline a false `sponsors` → PASS.
  - A requirement-word guard for restrictions (freehire tables: 101/102 kept) would drop short bullets such as "- U.S. citizenship" → silent PASS. Not recommended: a wrong FAIL shows its quote; a wrong PASS is silent.
  - A guard for the permissive `sponsors` claim (the sentence must also say offer / provide / support / available) only removes a permissive claim, so it cannot create a silent PASS. Recommended.
- **All 69 scored postings together (dev, holdout, holdout2, low): Spearman 0.74.**
- **After the `sponsors` guard (host rerun, 2026-09-28):** all five sets keep the same scores (Dev 10/10, Holdout 24/25, Holdout2 18/18, Low 13/17, GatesReal 16/16 not PASS). Two gate verdicts moved, both toward `/rank`: anchorline location PASS → FLAG, hireloom (Holdout2) location PASS → FLAG. wraithwork keeps its false citizenship FAIL by choice (see above).

### 7.3c Rerun after anonymization (iOS 27 simulator, 2026-10-11)

Issue #3 replaced every employer name in the fixtures with a fictional one (file names, posting text, URLs) and removed third-party names (founders, recruiters, LinkedIn sidebar). Expected bands, `/rank` scores, `CandidateProfile.fixture`, prompts and FitRubric tables did not change. Runner: `xcodebuild test` on the iOS 27.0 simulator (iPhone 18 Pro, host model, greedy). The "Before" numbers are the last host run (§7.3a, §7.3b) and, for dev, the last simulator run (§7.3).

| Set | Before: within 1 / exact / MAE / bias / Spearman | After | Notes |
|---|---|---|---|
| Dev | 10/10, 6, 6.1, +2.9, 0.84 (host); 9/10, 6, 6.0, +2.4, 0.89 (simulator) | **9/10**, 6, 6.0, +2.4, 0.89 (scored 9) | variantly fails with `guardrailViolation` ("The on-device safety filter blocked this posting"), as in the earlier simulator run. Identical to the earlier simulator numbers. |
| Holdout | 24/25, 14, 8.3, +3.8, 0.86 (host) | **25/25**, 13, 7.9, +4.4, 0.82 | threadly now parses. The host miss was `unsupportedLanguageOrLocale` on the real name, a Polish word; the fictional name does not trigger it. |
| Holdout2 | 18/18, 10, 6.0, +0.2, 0.66 (host) | **18/18**, 10, 6.2, +0.1, 0.57 | |
| Low | 13/17, 7, 18.1, +14.6, 0.08 (host) | **13/17**, 7, 17.9, +14.8, 0.19 | Same 4 misses class: quickwrite (citizenship FAIL from page chrome → Poor Fit vs Strong), datavane (Polish requirement missed), anchorline and dentiform (over-scored). Bias is still about +15. |
| GatesReal | 16/16 not PASS (host) | **16/16** not PASS | All 16: eligibility PASS, location FLAG. Now a test: `EvalTests.gatesRealPostingsAreNeverPlacePass`, bar 15. |
| Gate injection | 17/17 (simulator) | **17/17** | |

- The first GatesReal run hit its 30-minute limit on the last posting (suites run in parallel); the limit is now 60 minutes and the rerun alone took 34 minutes.
- No number moved by more than the run-to-run noise seen before (§7.3a), except the threadly fix that came from the name change itself.

### 7.4 Gate injection: one inserted sentence per case

Two dev postings (tbd, sandboxly), 10 sentences each (`Tests/DeviceTests/GateInjectionTests.swift`).

- **Before the fix, eligibility caught 1 of 8 sentences.** "Applicants must be U.S. citizens." came back as `locationRequirement: ["United States"]` with `visaSponsorship: silent`. Only "unable to sponsor" worked.
- **Language and location caught 5 of 5** on tbd.
- **A guardrail stopped the sandboxly run:** "We are unable to sponsor work visas for this position." raised `guardrailViolation` on an ordinary posting.
- **Fix:** `Grounding.statedRestriction` finds a citizenship, clearance or work-authorization sentence and upgrades the stance; it never lowers a stricter one. On the 35 eval postings it changes two verdicts, both to FLAG: nimbara ("must be authorized to work in the country", `/rank` FAIL) and halcyon ("unable to provide visa sponsorship", `/rank` PASS). Equal-opportunity text and "company-sponsored trips" do not count.
- **After the fix (iOS 27 simulator, 2026-09-28): 17 of 20, below the bar of 18.**
  - Eligibility 9 of 10. The miss is the guardrail case: the posting cannot be parsed at all.
  - Language 4 of 4.
  - Location 4 of 6. Both misses are on sandboxly, whose own text says "remote, globally distributed". The inserted "hybrid, 3 days in Berlin" and "work from anywhere" conflict with it, so the expected verdict is ambiguous. Proposed: run location cases on the tbd base only (it states no remote policy).
- **Guardrail retry (host, 2026-09-28):** the same sandboxly text without the lines that contain "visa" or "sponsor" parses, and grounding on the full text still gives eligibility FLAG with the quote. Built as `Truncator.droppingVisaLines` + one retry in `FoundationModelsClient.generate`.
- **After both fixes (iOS 27 simulator, 2026-09-28): 17 of 17** (bar 16). Location cases now run on the tbd base only. The sandboxly guardrail case returns FLAG with the quote.

### 7.5 How D scores (`Core/Rubric/FitRubric.swift`)

- **Technical:** each must-have item and each `stack` item maps to a rubric area of 04-job-evaluation.md: strong 1.0, moderate 0.65, weak 0.25, not in the lexicon 0.5. Soft skills, degrees and languages are ignored. Technical = 20 + 75 × mean, or 60 when nothing maps.
- **Experience:** a table by `roleFocus` (llmApplications 85 … management 30), +5 when LLM work is the core of a non-LLM role.
- **Career:** `llmWork` core 85, part 65, none 45; capped for mlModeling 50, aiTrainingData 40, dataEngineering 35, management 30.
- **Behavioral:** 65; consulting 55, management 50. Nothing in a posting predicts it well, and it weighs 15 %.
- **Strengths and gaps:** the posting's own skill words and must-have items, so every bullet is grounded by construction.
- **Calibration knobs:** the numbers in these tables. Change them only against the dev set, then score the holdout once.
- **The lexicon and the tables encode this one candidate.** Phase 1 of `docs/PRODUCT_PLAN.md` takes skill lists from the selected resume. FitRubric then reads its strong / moderate / weak lists from that resume; the digest prompt needs no change.

---

## 8. Open work

1. **Measure on the iPhone 16e:** speed and the eval set. `contextSize` is measured: 4096, so `profile_full.md` never runs on this device.
2. ~~Deterministic technical score~~ and ~~calibration anchors~~: done and tested in §7. Anchors failed; Swift tables replaced model scoring.
3. **Fix `llmWork` recall.** Holdout misses: stayloft, k-vanta and lattice-motion got `none` or `part` for AI roles.
   - **Rejected (2026-09-28): a Swift floor** "≥ 2 LLM terms in `mustHave` + summary → at least `part`". It fires on 0 dev postings. On the holdout it misses the targets (stayloft has 0 LLM terms in its digest, k-vanta has 1) and moves zephyra (52) and northvale-databricks (37) away from `/rank`.
   - **Rejected (2026-09-28): an evidence quote before `llmWork`** plus a Swift floor. Dev fell from 10/10, exact 6, Spearman 0.88 to 9/10, exact 5, Spearman 0.77 (details: `docs/RESEARCH.md` §3.1).
   - The digest itself drops the LLM part of stayloft ("one part of a broad product role" in `/rank`). The fix has to change what the digest lists, not how Swift reads it.
   - **No clean test set is left.** The holdout was seen 3 times. Of 10 more ranked postings in `seen_jobs.json`, 2 are usable English text (the others: HTTP 403/999, empty pages, Russian page chrome). Run `/scrape` + `/rank` for about 20 new English postings before the next prompt change.
4. **Strip page chrome before the model call.** threadly fails on its page header (§7.3).
5. **Check the guardrails** on security postings ("penetration tester", "malware analyst"). None appear in the eval set.
6. **Improve stack recall.** `PostingDigest.mustHave` now carries the requirements into the technical score; `stack` recall is still 2–3 of about 10 tools.
7. **Eval catalog:** `docs/EVALS.md` lists the checks that exist and the ones still to build.
