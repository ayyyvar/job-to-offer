# App Review notes: job-to-offer

## Sample posting

Use this public Greenhouse job URL to test:

https://job-boards.greenhouse.io/anthropic/jobs/4461450008

Any public Greenhouse, Lever, or Ashby job URL works. Any other public job posting URL works too: the app reads its text.

## Requirements for the reviewer's device

- iPhone 15 Pro or later with Apple Intelligence turned on. The app parses postings with Apple's on-device model; it does not run on devices without Apple Intelligence. The app still opens and shows the setup status in Settings.
- English device language and English Siri language.
- English job postings. Other languages are not supported in V1.

## Account and login

None. The app has no sign-in, no account, and no server.

## Network use

The app makes one fetch for each URL the user shares or pastes:

- the shared URL itself, to read the posting; or
- for a Greenhouse, Lever, or Ashby URL, the matching public job API for that same posting.

The app does not crawl sites, does not scrape job boards, and does not fetch other pages.

## Steps to test

1. Open job-to-offer.
2. Optional: go to Settings → Profile and add regions, languages, and a resume (paste text or import a file). The app works without a profile; gates then show "unverified" where a profile is needed.
3. In Safari, open the sample URL above and tap Share → job-to-offer ("Add to job-to-offer"). Or copy the URL and paste it in the Inbox.
4. In the Inbox, tap Parse.
5. Open the job. Read the verdict, the eligibility, language, and location checks, and the quoted sentence behind any FAIL or FLAG.
6. Tap Add to tracker.
7. Open the Tracker and tap export. Choose a destination in the share sheet. Export runs only on this tap.

## Notes on AI output

Parsed fields and the fit estimate are AI-generated. The app labels them as such, and every field is editable before the job goes to the tracker.
