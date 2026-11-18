#!/bin/zsh
# Archive Fretty and upload it to App Store Connect / TestFlight.
# Requires an Apple ID for team RSDJXF7DXN signed in under Xcode ▸ Settings ▸ Accounts.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate -q
rm -rf build/Fretty.xcarchive
xcodebuild -project Fretty.xcodeproj -scheme Fretty -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Fretty.xcarchive \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/Fretty.xcarchive \
  -exportOptionsPlist scripts/ExportOptions.plist -exportPath build/export \
  -allowProvisioningUpdates
echo "Uploaded. The build appears in TestFlight once App Store Connect finishes processing it."
