#!/usr/bin/env bash
# locals-ios SSH-headless TestFlight ship driver. Run ON SY094.
#
#   ssh user276189@SY094.macincloud.com 'bash -lc "~/Desktop/projects/locals-ios/scripts/ship.sh"'
#
# Bumps CURRENT_PROJECT_VERSION in project.yml, regenerates Xcode project via
# xcodegen, archives + exports + uploads to TestFlight via altool.
#
# Mirrors glovebox-ios/scripts/ship.sh per ios-app-asc-headless-ship-protocol.

set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/Desktop/projects/locals-ios}"
KEY_ID="R8P6K38X47"
ISSUER="4b45186b-49e4-4a25-8a63-afd28cf12d3f"
P8="$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
TEAM_ID="86PUY7393S"
KEYCHAIN_PW="${KEYCHAIN_PASSWORD:-xve24085ehi}"
XCODEGEN="$HOME/bin/xcodegen"

cd "$REPO_DIR"

echo "==> [1] git pull"
git fetch origin main
git checkout main
git pull --ff-only origin main

echo "==> [2] bump CURRENT_PROJECT_VERSION in project.yml"
CUR=$(grep -E '^\s*CURRENT_PROJECT_VERSION:' project.yml | head -1 | grep -oE '"[0-9]+"' | tr -d '"')
NEXT=$((CUR + 1))
sed -i.bak "s/CURRENT_PROJECT_VERSION: \"$CUR\"/CURRENT_PROJECT_VERSION: \"$NEXT\"/" project.yml
rm project.yml.bak
echo "    build number: $CUR -> $NEXT"

echo "==> [3] xcodegen generate"
"$XCODEGEN" generate 2>&1 | tail -3

echo "==> [4] unlock keychain"
security unlock-keychain -p "$KEYCHAIN_PW" ~/Library/Keychains/login.keychain-db
security set-keychain-settings -lut 7200 ~/Library/Keychains/login.keychain-db

ARCHIVE="/tmp/locals-1.0.0.${NEXT}.xcarchive"
IPA_DIR="/tmp/locals-ipa-${NEXT}"
rm -rf "$ARCHIVE" "$IPA_DIR"

echo "==> [5] archive"
xcodebuild -project Locals.xcodeproj -scheme Locals -configuration Release \
  -archivePath "$ARCHIVE" \
  -destination "generic/platform=iOS" archive \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$P8" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER" \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic 2>&1 | tail -6

echo "==> [6] export IPA"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$IPA_DIR" \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$P8" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER" 2>&1 | tail -5

ls -la "$IPA_DIR"

echo "==> [7] altool upload"
xcrun altool --upload-app -f "$IPA_DIR/Locals.ipa" -t ios \
  --apiKey "$KEY_ID" \
  --apiIssuer "$ISSUER" 2>&1 | tail -10

echo "==> [8] commit + push build bump"
git add project.yml
git -c user.email="219926280+EcodiaTate@users.noreply.github.com" \
    -c user.name="EcodiaTate" \
    commit -m "chore(ship): bump CURRENT_PROJECT_VERSION $CUR -> $NEXT (TestFlight upload)" \
    || echo "    no changes to commit"
git push origin main || echo "    push deferred (network/auth)"

echo "==> done. build 1.0.0($NEXT) uploaded to ASC for au.ecodia.locals"
