#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

pass() {
  echo "[PASS] $*"
  PASS_COUNT=$((PASS_COUNT + 1))
}

warn() {
  echo "[WARN] $*"
  WARN_COUNT=$((WARN_COUNT + 1))
}

fail() {
  echo "[FAIL] $*"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

check_file_exists() {
  local path="$1"
  if [[ -f "$path" ]]; then
    pass "Found file: $path"
  else
    fail "Missing file: $path"
  fi
}

check_required_files() {
  printf "\n== Required Files ==\n"
  check_file_exists "ios/Kinex Fit.entitlements"
  check_file_exists "ios/KinexFit/Resources/Info.plist"
  check_file_exists "ios/KinexFitShareExtension/Info.plist"
  check_file_exists "ios/KinexFitShareExtension/KinexFitShareExtension.entitlements"
  check_file_exists "ios/KinexFit/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json"
  check_file_exists "ios/KinexFit/Resources/Assets.xcassets/LaunchScreenBackground.colorset/Contents.json"
  check_file_exists "ios/project.yml"
  check_file_exists "ios/Kinex Fit.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
}

check_plists() {
  printf "\n== Plist/Entitlement Lint ==\n"
  if plutil -lint \
    "ios/Kinex Fit.entitlements" \
    "ios/KinexFit/Resources/Info.plist" \
    "ios/KinexFitShareExtension/Info.plist" \
    "ios/KinexFitShareExtension/KinexFitShareExtension.entitlements" >/dev/null; then
    pass "Plist and entitlement lint passed"
  else
    fail "Plist and entitlement lint failed"
  fi

  local aps_env
  aps_env="$(/usr/libexec/PlistBuddy -c 'Print :aps-environment' 'ios/Kinex Fit.entitlements' 2>/dev/null || true)"
  if [[ "$aps_env" == "production" ]]; then
    pass "APNs entitlement is production"
  else
    fail "APNs entitlement is not production (found: ${aps_env:-<missing>})"
  fi
}

check_assets() {
  printf "\n== Asset Completeness ==\n"
  local icon_dir="ios/KinexFit/Resources/Assets.xcassets/AppIcon.appiconset"
  local required_icons=(
    "Icon-App-20x20@2x.png"
    "Icon-App-20x20@3x.png"
    "Icon-App-29x29@2x.png"
    "Icon-App-29x29@3x.png"
    "Icon-App-40x40@2x.png"
    "Icon-App-40x40@3x.png"
    "Icon-App-60x60@2x.png"
    "Icon-App-60x60@3x.png"
    "Icon-App-1024x1024@1x.png"
  )

  for icon in "${required_icons[@]}"; do
    if [[ -f "$icon_dir/$icon" ]]; then
      pass "App icon present: $icon"
    else
      fail "App icon missing: $icon"
    fi
  done
}

check_code_hygiene() {
  printf "\n== Code Hygiene ==\n"
  local findings
  findings="$(rg -n "TODO|FIXME" ios/KinexFit ios/KinexFitShareExtension || true)"
  if [[ -z "$findings" ]]; then
    pass "No TODO/FIXME markers in app or extension code"
  else
    fail "TODO/FIXME markers found"
    echo "$findings"
  fi
}

check_links_config() {
  printf "\n== Link Configuration ==\n"
  local links_file="ios/KinexFit/App/AppLinks.swift"
  if rg -q 'https://kinexfit.com/privacy' "$links_file" && \
     rg -q 'https://kinexfit.com/terms' "$links_file" && \
     rg -q 'https://kinexfit.com/support' "$links_file"; then
    pass "App links are explicit privacy/terms/support routes"
  else
    fail "App links are not configured with explicit privacy/terms/support routes"
  fi
}

check_legal_url_reachability() {
  printf "\n== Legal URL Reachability ==\n"
  local urls=(
    "https://kinexfit.com/privacy"
    "https://kinexfit.com/terms"
    "https://kinexfit.com/support"
  )

  for url in "${urls[@]}"; do
    local status
    status="$(curl -ILs -o /dev/null -w '%{http_code}' "$url" || echo "000")"
    if [[ "$status" == "200" ]]; then
      pass "URL reachable (200): $url"
    else
      fail "URL not ready (status $status): $url"
    fi
  done
}

run_xcodegen_validation() {
  printf "\n== XcodeGen Validation ==\n"
  if ! command -v xcodegen >/dev/null 2>&1; then
    warn "xcodegen not installed; skipping project generation check"
    return
  fi

  if (cd ios && xcodegen generate >/tmp/phase6_xcodegen.log 2>&1); then
    pass "xcodegen generate succeeded"
  else
    fail "xcodegen generate failed"
    cat /tmp/phase6_xcodegen.log
  fi
}

run_optional_xcodebuild_checks() {
  printf "\n== Optional xcodebuild Checks ==\n"
  if [[ "${RUN_XCODEBUILD:-0}" != "1" ]]; then
    warn "Skipping xcodebuild checks (set RUN_XCODEBUILD=1 to enable)"
    return
  fi

  if [[ ! -d "/Applications/Xcode.app" ]]; then
    fail "Xcode.app not found at /Applications/Xcode.app"
    return
  fi

  local developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
  local timeout_cmd=()

  if command -v gtimeout >/dev/null 2>&1; then
    timeout_cmd=(gtimeout 600)
  elif command -v timeout >/dev/null 2>&1; then
    timeout_cmd=(timeout 600)
  else
    warn "No timeout command found; skipping xcodebuild to avoid hangs"
    return
  fi

  if "${timeout_cmd[@]}" env DEVELOPER_DIR="$developer_dir" xcodebuild -list -project "ios/Kinex Fit.xcodeproj" >/tmp/phase6_xcodebuild_list.log 2>&1; then
    pass "xcodebuild -list succeeded"
  else
    fail "xcodebuild -list failed or timed out"
    cat /tmp/phase6_xcodebuild_list.log
  fi

  if "${timeout_cmd[@]}" env DEVELOPER_DIR="$developer_dir" xcodebuild \
    -project "ios/Kinex Fit.xcodeproj" \
    -scheme "Kinex Fit" \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    build >/tmp/phase6_xcodebuild_build.log 2>&1; then
    pass "xcodebuild Debug simulator build succeeded"
  else
    fail "xcodebuild Debug simulator build failed or timed out"
    cat /tmp/phase6_xcodebuild_build.log
  fi
}

print_summary_and_exit() {
  printf "\n== Summary ==\n"
  echo "Passed: $PASS_COUNT"
  echo "Warnings: $WARN_COUNT"
  echo "Failed: $FAIL_COUNT"

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
  fi

  exit 0
}

check_required_files
check_plists
check_assets
check_code_hygiene
check_links_config
check_legal_url_reachability
run_xcodegen_validation
run_optional_xcodebuild_checks
print_summary_and_exit
