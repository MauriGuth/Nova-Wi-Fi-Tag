#!/usr/bin/env bash
# Archiva la app (con el App Clip embebido) y la exporta/sube según ExportOptions.plist.
# Requiere: Team ID configurado (scripts/set-team-id.sh) y Xcode con la cuenta de Developer iniciada.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ARCHIVE="build/NovaWifiTag.xcarchive"
xcodegen generate
xcodebuild -project NovaWifiTag.xcodeproj -scheme NovaWifiTag -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" archive -allowProvisioningUpdates
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates
echo "Archivo: $ARCHIVE"
echo "Tamaño del App Clip:"
du -sh "$ARCHIVE/Products/Applications/NovaWifiTag.app/AppClips/"*.app 2>/dev/null || true
