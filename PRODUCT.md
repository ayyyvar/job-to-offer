# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Job seekers from the CIS who look for work across borders: remote roles worldwide or relocation with visa sponsorship. They find postings on LinkedIn, Telegram channels and company career pages, mostly on the phone, and share each posting into the app. The first audience is about 10 testers from cross-border job-seeker and relocation communities (docs/PRODUCT_PLAN.md, Phase 2). They are strangers to the app: no onboarding by the author.

## Product Purpose

Share a posting, get a verdict in about 10 seconds: can you legally take this job (eligibility, language, location), and how well do you fit. Then keep the job in a tracker until it closes. Success: testers come back in week 2 and agree with the verdicts.

## Positioning

The gates are deterministic Swift, not model opinion. Every FAIL or FLAG quotes the sentence from the posting as proof. Everything runs on the phone: free, private, works offline, no account. Siri and generic AI tools missed location or visa limits in 3 of 3 tested postings; the gates flagged all 3.

## Operating Context

- Entry: the iOS share sheet from Safari, LinkedIn or Telegram; paste from the clipboard.
- Sources: Greenhouse, Lever and Ashby job APIs; any other URL as HTML text.
- The candidate profile (regions, languages, skills from an imported resume) drives the gates and the fit estimate.
- Tracker statuses: drafted, applied, interview, offer, hired, rejected, no_response, offer_declined, withdrawn. Export for the author's own tools.

## Capabilities and Constraints

- iOS 27, SwiftUI, Apple Intelligence devices only (iPhone 15 Pro and later). English postings only.
- The fit score is an estimate: it over-scores weak jobs. The verdict and the quote lead; the score follows.
- Model output is marked AI-generated and every field is editable (Apple HIG, Generative AI).
- System navigation stays native: tab bar, back button, sheets. Content surfaces are custom (user decision, 2026-10-12).

## Brand Commitments

- Name: job-to-offer.
- User-facing words: free, private, works offline, export. Never: token, PCC, on-device model, CSV.
- Not a dark "hacker" terminal look; not a corporate HR SaaS look (user, 2026-10-12).

## Evidence on Hand

- Eval results in docs/MODEL_BEHAVIOR.md and docs/EVALS.md (dev set 10/10 within one band, holdout 24/25).
- Mock screenshot data in JobToOfferApp/MockData.swift (fictional companies).
- No testimonials, users, press or pricing yet. Do not invent them.

## Product Principles

1. The verdict first, the quote as proof, the score last.
2. Uncertain means "not sure, check yourself", never a silent PASS.
3. One share, one answer: no setup in the path from a posting to a verdict once the profile exists.
4. The phone keeps the data; say so in plain words.
