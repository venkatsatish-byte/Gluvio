#!/usr/bin/env bash
# Builds Gluvio and opens it in the iPhone simulator (and optionally the Apple
# Watch simulator) on your Mac.
#
#   ./scripts/run-on-mac.sh            start fresh, at the welcome screen
#   ./scripts/run-on-mac.sh --demo     open with 30 days of sample data
#   ./scripts/run-on-mac.sh --watch    also run the Apple Watch app
#   ./scripts/run-on-mac.sh --family   sample caregiver family and Parent Dashboard
#   ./scripts/run-on-mac.sh --kid      sample family, straight into Kid Mode (parent PIN 1234)
#
# Needs Xcode (free from the Mac App Store). Installs XcodeGen with Homebrew
# if it's missing.
set -euo pipefail
cd "$(dirname "$0")/.."

DEMO=NO
WATCH=NO
FAMILY=NO
KID=NO
OPEN_SIMULATOR=YES
for arg in "$@"; do
  case "$arg" in
    --demo) DEMO=YES ;;
    --watch) WATCH=YES ;;
    --family) DEMO=YES; FAMILY=YES ;;
    --kid) DEMO=YES; FAMILY=YES; KID=YES ;;
    --no-open) OPEN_SIMULATOR=NO ;;   # used by CI, which has no screen
    -h|--help) sed -n 2,12p "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)"; exit 1 ;;
  esac
done

BUNDLE_ID=com.example.gluvio
LOG=build/run-on-mac.log
mkdir -p build

step() { printf '\n▶ %s\n' "$1"; }
fail() { printf '\n✖ %s\n' "$1"; exit 1; }

step "Checking Xcode"
if ! xcodebuild -version > /dev/null 2>&1; then
  fail "Xcode isn't ready. Install Xcode from the Mac App Store, open it once to finish setup, then run:
    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi
xcodebuild -version | head -1

step "Checking XcodeGen"
if ! command -v xcodegen > /dev/null; then
  command -v brew > /dev/null || fail "Homebrew is needed to install XcodeGen. Install it from https://brew.sh, then run this again."
  brew install xcodegen
fi
xcodegen generate > /dev/null
echo "Generated Gluvio.xcodeproj"

# Newest available simulator of a kind ("iOS" or "watchOS").
pick() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
kind = sys.argv[1]
candidates = []
for runtime, items in json.load(sys.stdin)["devices"].items():
    if kind + "-" not in runtime:
        continue
    version = [int(x) for x in runtime.rsplit(".", 1)[-1].split("-")[1:]]
    for d in items:
        name = d["name"]
        if kind == "iOS" and name.startswith("iPhone"):
            preferred = "Pro" in name and "Max" not in name
        elif kind == "watchOS" and name.startswith("Apple Watch"):
            preferred = "Series" in name
        else:
            continue
        candidates.append((version, preferred, d["udid"], name))
best = max(candidates) if candidates else None
print(f"{best[2]}|{best[3]}" if best else "")
' "$1"
}

# Builds for the simulator. Ad-hoc signing keeps the HealthKit entitlement, so
# Apple Health works in the simulator without an Apple Developer account.
build() {
  local scheme=$1 device=$2
  if ! xcodebuild -project Gluvio.xcodeproj -scheme "$scheme" -configuration Debug \
       -destination "id=$device" -derivedDataPath build/DerivedData \
       CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= \
       build > "$LOG" 2>&1; then
    grep -E "error:" "$LOG" | sort -u | head -20 || true
    fail "The $scheme build failed. The full log is in $LOG. Paste the errors above into the chat."
  fi
}

launch_args=()
[ "$DEMO" = YES ] && launch_args=(-demoMode YES)
[ "$FAMILY" = YES ] && launch_args+=(-demoFamily YES)
[ "$KID" = YES ] && launch_args+=(-kidMode Aarav)

step "Finding an iPhone simulator"
IFS='|' read -r IPHONE IPHONE_NAME <<< "$(pick iOS)"
[ -n "${IPHONE:-}" ] || fail "No iPhone simulator found. In Xcode open Settings → Components and install the iOS simulator."
echo "$IPHONE_NAME"

step "Building the iPhone app (the first build takes a few minutes)"
build Gluvio "$IPHONE"
echo "Built"

step "Opening the iPhone simulator"
xcrun simctl boot "$IPHONE" 2> /dev/null || true
[ "$OPEN_SIMULATOR" = YES ] && open -a Simulator
xcrun simctl bootstatus "$IPHONE" -b > /dev/null
xcrun simctl install "$IPHONE" build/DerivedData/Build/Products/Debug-iphonesimulator/Gluvio.app
xcrun simctl terminate "$IPHONE" "$BUNDLE_ID" 2> /dev/null || true
xcrun simctl launch "$IPHONE" "$BUNDLE_ID" ${launch_args[@]+"${launch_args[@]}"} > /dev/null
echo "Gluvio is running on $IPHONE_NAME"

if [ "$WATCH" = YES ]; then
  step "Finding an Apple Watch simulator"
  IFS='|' read -r WATCH_ID WATCH_NAME <<< "$(pick watchOS)"
  [ -n "${WATCH_ID:-}" ] || fail "No Apple Watch simulator found. In Xcode open Settings → Components and install the watchOS simulator."
  echo "$WATCH_NAME"

  step "Building the Apple Watch app"
  build GluvioWatch "$WATCH_ID"
  echo "Built"

  step "Opening the Apple Watch simulator"
  xcrun simctl boot "$WATCH_ID" 2> /dev/null || true
  xcrun simctl bootstatus "$WATCH_ID" -b > /dev/null
  xcrun simctl install "$WATCH_ID" build/DerivedData/Build/Products/Debug-watchsimulator/GluvioWatch.app
  xcrun simctl launch "$WATCH_ID" "$BUNDLE_ID.watchkitapp" ${launch_args[@]+"${launch_args[@]}"} > /dev/null
  echo "Gluvio is running on $WATCH_NAME"
fi

cat <<'TIPS'

✔ Done. Things to try:
  • --family: Family tab → Aarav or Meera for the Parent Dashboard, then "Start Kid Mode".
  • --kid: Kid Mode for Aarav. Tap the lock (top right) and enter 1234 to leave.
  • Welcome screen → "Explore with sample data" to see every screen filled in,
    or go through onboarding and log readings yourself (+ button, top right).
  • Enter a reading below 54 mg/dL to see the urgent guidance screen.
  • Meals tab → + to log a meal; Settings → Doctor report to create a PDF.
  • The simulator's Health app works too: Browse → Other Data → Blood Glucose → Add Data.
  • To change code, open Gluvio.xcodeproj in Xcode and press ▶ Run.
TIPS
