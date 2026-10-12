#!/usr/bin/env bash
# Interactive walkthrough of the App Store v1.0.0 release steps that only a human can do.
# Usage: scripts/release-wizard.sh [--from N]    (N = 1..11, resumes at step N)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
LOCAL_XCCONFIG="$ROOT/Local.xcconfig"
SCHEME=JobScout
WORKSPACE=JobScout.xcworkspace
SIM_NAME="iPhone 18 Pro"
SIM_DEST="platform=iOS Simulator,name=$SIM_NAME,OS=27.0"
TEAM_RE='^[A-Z0-9]{10}$'
BUNDLE_RE='^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$'

TEAM_ID="${TEAM_ID:-}"
BUNDLE_ID="${BUNDLE_ID:-}"
APP_GROUP="${APP_GROUP:-}"
CURRENT=1

die() {
  echo "ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: $0 [--from N]

Walks through the App Store v1.0.0 release steps 1-11.
  --from N   resume at step N (1-11)
EOF
}

header() {
  printf '\n== Step %s/11: %s ==\n' "$1" "$2"
}

# Read one value from Local.xcconfig; prints nothing when the file or key is missing.
get_cfg() {
  [[ -f "$LOCAL_XCCONFIG" ]] || return 0
  sed -n "s/^$1[[:space:]]*=[[:space:]]*//p" "$LOCAL_XCCONFIG" | tail -n 1 | sed 's/[[:space:]]*$//'
}

# ask_value PROMPT REGEX ERROR [DEFAULT]: prints the first input that matches REGEX.
ask_value() {
  local prompt="$1" re="$2" err="$3" default="${4:-}" v
  while true; do
    if [[ -n "$default" ]]; then
      read -r -p "$prompt [$default]: " v || die "No input. Stopped at step $CURRENT; resume with --from $CURRENT."
      v="${v:-$default}"
    else
      read -r -p "$prompt: " v || die "No input. Stopped at step $CURRENT; resume with --from $CURRENT."
    fi
    if [[ "$v" =~ $re ]]; then
      printf '%s\n' "$v"
      return 0
    fi
    echo "  Invalid: $err" >&2
  done
}

valid_bundle() {
  [[ "$1" =~ $BUNDLE_RE && "$1" != com.example.* ]]
}

# ask_bundle [DEFAULT]: prints a bundle ID that is not com.example.*.
ask_bundle() {
  local def="${1:-}" v
  while true; do
    v="$(ask_value "Bundle ID" "$BUNDLE_RE" "use reverse-DNS form, like com.name.jobscout" "$def")"
    if valid_bundle "$v"; then
      printf '%s\n' "$v"
      return 0
    fi
    echo "  Invalid: com.example.* is reserved for the template. Choose your own." >&2
    def=""
  done
}

confirm() {
  local a
  read -r -p "$1 [y/N] " a || a=""
  [[ "$a" =~ ^[Yy]$ ]]
}

pause() {
  read -r -p "Done? [Enter]" _ || die "No input. Stopped at step $CURRENT; resume with --from $CURRENT."
}

# run CMD...: shows the command, asks for y/N, runs it, stops the script on failure.
run() {
  printf '  $ %s\n' "$*"
  if confirm "  Run this command?"; then
    if ! "$@"; then
      die "Command failed. Fix the problem, then resume with: $0 --from $CURRENT"
    fi
  else
    echo "  Skipped. Run it yourself before you continue."
  fi
}

ensure_team() {
  if [[ ! "$TEAM_ID" =~ $TEAM_RE ]]; then
    TEAM_ID="$(get_cfg DEVELOPMENT_TEAM)"
    if [[ ! "$TEAM_ID" =~ $TEAM_RE ]]; then
      TEAM_ID="$(ask_value "Team ID (from step 1)" "$TEAM_RE" "must be 10 characters, A-Z and 0-9 only")"
    fi
  fi
}

ensure_bundle() {
  if ! valid_bundle "$BUNDLE_ID"; then
    BUNDLE_ID="$(get_cfg APP_BUNDLE_ID)"
    if ! valid_bundle "$BUNDLE_ID"; then
      BUNDLE_ID="$(ask_bundle "")"
    fi
  fi
  APP_GROUP="group.$BUNDLE_ID"
}

step_1() {
  header 1 "Apple Developer Program and Team ID"
  cat <<'EOF'
  1. Open https://developer.apple.com/account
  2. Confirm the Apple Developer Program membership is active (not expired, not pending).
  3. Copy the Team ID (10 characters, under Membership details).
EOF
  TEAM_ID="$(ask_value "Team ID" "$TEAM_RE" "must be 10 characters, A-Z and 0-9 only" "$(get_cfg DEVELOPMENT_TEAM)")"
  echo "  Team ID saved for this run: $TEAM_ID"
  pause
}

step_2() {
  header 2 "Bundle ID and Local.xcconfig"
  ensure_team
  cat <<'EOF'
  The bundle ID must be yours. com.example.jobscout is the template default and is not allowed.
EOF
  local name current suggest content
  name="$(ask_value "Short name (lowercase letters and digits, e.g. jdoe)" '^[a-z0-9]+$' "use lowercase letters and digits only")"
  current="$(get_cfg APP_BUNDLE_ID)"
  if valid_bundle "$current"; then
    suggest="$current"
  else
    suggest="com.$name.jobscout"
  fi
  BUNDLE_ID="$(ask_bundle "$suggest")"
  APP_GROUP="group.$BUNDLE_ID"

  content="$(printf '%s\n' \
    "// Written by scripts/release-wizard.sh. Gitignored." \
    "APP_BUNDLE_ID = $BUNDLE_ID" \
    "APP_GROUP_ID = $APP_GROUP" \
    "DEVELOPMENT_TEAM = $TEAM_ID")"

  echo "  --- $LOCAL_XCCONFIG ---"
  printf '%s\n' "$content" | sed 's/^/  /'
  echo "  ---"
  if confirm "  Write this file (overwrites an existing Local.xcconfig)?"; then
    printf '%s\n' "$content" > "$LOCAL_XCCONFIG"
    echo "  Written: $LOCAL_XCCONFIG"
  else
    echo "  Not written. Steps 3 to 8 need it."
  fi
  pause
}

step_3() {
  header 3 "Register the App IDs and the App Group"
  ensure_bundle
  cat <<EOF
  Open https://developer.apple.com/account/resources/identifiers/list

  App ID 1, the app:
    - Identifiers > + > App IDs > App
    - Description: job-to-offer
    - Bundle ID (Explicit): $BUNDLE_ID
    - Capabilities: enable App Groups

  App ID 2, the share extension:
    - Identifiers > + > App IDs > App
    - Bundle ID (Explicit): $BUNDLE_ID.ShareExtension
    - Capabilities: enable App Groups

  App Group:
    - Identifiers > + > App Groups
    - Identifier: $APP_GROUP
    - Then open each App ID above > App Groups > Configure > select $APP_GROUP

  Shortcut: Xcode automatic signing with -allowProvisioningUpdates (used in step 8)
  creates these IDs and the group for you. Check them here either way.
EOF
  pause
}

step_4() {
  header 4 "Generate the Xcode project"
  cat <<'EOF'
  xcodegen reads Signing.xcconfig and Local.xcconfig and writes JobScout.xcodeproj (gitignored).
EOF
  command -v xcodegen >/dev/null 2>&1 || die "xcodegen not found. Install it: brew install xcodegen"
  run xcodegen generate
  pause
}

step_5() {
  header 5 "Create the App Store Connect record"
  ensure_bundle
  cat <<EOF
  Open https://appstoreconnect.apple.com/apps > + > New App
    - Platform: iOS
    - Name: use the name in docs/appstore/listing.md
    - Primary language: English (U.S.)
    - Bundle ID: $BUNDLE_ID   (must exist from step 3)
    - SKU: jobscout-ios
    - User access: Full Access
EOF
  if [[ -f "$ROOT/docs/appstore/listing.md" ]]; then
    echo "  Listing text: docs/appstore/listing.md"
  else
    echo "  WARNING: docs/appstore/listing.md not found. Create it before you fill in the listing."
  fi
  pause
}

step_6() {
  header 6 "Privacy policy URL and privacy label"
  cat <<'EOF'
  A. Publish the privacy policy (GitHub Pages):
     1. Open https://github.com/ayyyvar/jobscout/settings/pages
     2. Source: Deploy from a branch > main > /docs > Save
     3. The repo must be public for Pages on a free account.
     4. Check: https://ayyyvar.github.io/jobscout/privacy.html opens.

  B. Set the URL in App Store Connect:
     App Information > Privacy Policy URL:
     https://ayyyvar.github.io/jobscout/privacy.html

  C. Privacy label: App Privacy in App Store Connect. Follow docs/appstore/privacy-label.md.
EOF
  [[ -f "$ROOT/docs/privacy.html" ]] || echo "  WARNING: docs/privacy.html not found. Pages will return 404."
  [[ -f "$ROOT/docs/appstore/privacy-label.md" ]] || echo "  WARNING: docs/appstore/privacy-label.md not found."
  if command -v gh >/dev/null 2>&1; then
    echo "  Repo visibility: $(gh repo view ayyyvar/jobscout --json visibility --jq .visibility 2>/dev/null || echo 'unknown')"
  fi
  pause
}

step_7() {
  header 7 "App Store screenshots (6.9-inch)"
  ensure_bundle
  cat <<EOF
  The script boots the "$SIM_NAME" simulator, builds the app, and launches it with -mockData YES.
  Then navigate to each screen and press Enter to capture it.
  Suggested screens: Inbox, Job detail (gate verdicts and score), Tracker, Settings.
EOF
  if ! xcrun simctl list devices booted | grep -q "$SIM_NAME"; then
    run xcrun simctl boot "$SIM_NAME"
  fi
  open -a Simulator || true
  run xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration Debug \
    -destination "$SIM_DEST" -derivedDataPath build/DerivedData build
  run xcrun simctl install booted "$ROOT/build/DerivedData/Build/Products/Debug-iphonesimulator/JobScout.app"
  run xcrun simctl launch booted "$BUNDLE_ID" -mockData YES

  mkdir -p "$ROOT/docs/appstore/screenshots"
  local i=1 a f w h
  while true; do
    read -r -p "Screen $i ready? Press Enter to capture, or q to stop: " a || a=q
    [[ "$a" == q || "$a" == Q ]] && break
    f="$(printf '%s/docs/appstore/screenshots/%02d.png' "$ROOT" "$i")"
    xcrun simctl io booted screenshot "$f"
    w="$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}')"
    h="$(sips -g pixelHeight "$f" | awk '/pixelHeight/{print $2}')"
    echo "  Saved: $f (${w} x ${h})"
    if [[ "$w" != 1320 || "$h" != 2868 ]]; then
      echo "  WARNING: 6.9-inch App Store size is 1320 x 2868. Check the simulator model or resize."
    fi
    i=$((i + 1))
  done
  pause
}

step_8() {
  header 8 "Archive and upload"
  ensure_team
  ensure_bundle
  mkdir -p "$ROOT/build"
  cat > "$ROOT/build/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF
  echo "  Wrote $ROOT/build/ExportOptions.plist (teamID $TEAM_ID)"
  cat <<'EOF'
  Two commands, each asks before it runs:
    1. Archive (Release)
    2. Export and upload to App Store Connect
EOF
  run xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=iOS' -archivePath build/JobScout.xcarchive \
    -allowProvisioningUpdates archive
  run xcodebuild -exportArchive -archivePath build/JobScout.xcarchive \
    -exportOptionsPlist build/ExportOptions.plist -exportPath build/export \
    -allowProvisioningUpdates
  echo "  Check the build: App Store Connect > TestFlight. Processing takes a few minutes."
  pause
}

step_9() {
  header 9 "TestFlight test on iPhone 16e"
  cat <<'EOF'
  1. Open the TestFlight app on the iPhone 16e and install job-to-offer (build from step 8).
  2. Test one posting per source. Use a real URL for each:
       - Greenhouse   (boards.greenhouse.io/...)
       - Lever        (jobs.lever.co/...)
       - Ashby        (jobs.ashbyhq.com/...)
       - LinkedIn     (linkedin.com/jobs/view/...)
  3. For each URL: Safari > Share > Add to job-to-offer, then Parse.
  4. Check: fields extracted, gate verdicts with quotes, score and band shown.
  5. Add to tracker, then export CSV and JSON from the Tracker screen.
  6. Save the exported files and open the CSV in a text editor. Check the 14 columns.
EOF
  pause
}

step_10() {
  header 10 "Submit for review"
  cat <<'EOF'
  1. Open https://appstoreconnect.apple.com/apps > job-to-offer > version 1.0.0.
  2. Select the processed build from step 8.
  3. App Review > Notes: paste the text from docs/appstore/review-notes.md.
  4. Answer the export-compliance and content questions on the form.
  5. Click Add for Review, then Submit to App Review.
EOF
  [[ -f "$ROOT/docs/appstore/review-notes.md" ]] || echo "  WARNING: docs/appstore/review-notes.md not found."
  pause
}

step_11() {
  header 11 "Tag the release"
  if git rev-parse -q --verify refs/tags/v1.0.0 >/dev/null; then
    echo "  Tag v1.0.0 already exists locally. Skipping the tag step."
  else
    run git tag v1.0.0
  fi
  run git push origin v1.0.0
  pause
}

# --- argument parsing ---
FROM=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)
      [[ $# -ge 2 ]] || die "--from needs a step number (1-11)"
      FROM="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

[[ "$FROM" =~ ^([1-9]|1[01])$ ]] || die "--from needs a step number from 1 to 11, got: $FROM"

CURRENT="$FROM"
while (( CURRENT <= 11 )); do
  "step_$CURRENT"
  CURRENT=$((CURRENT + 1))
done

echo
echo "Release wizard finished. Next: check App Store Connect for the review status."
