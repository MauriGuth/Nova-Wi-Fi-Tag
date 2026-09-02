#!/usr/bin/env bash
# Genera el proyecto con XcodeGen y compila app + App Clip para el simulador (sin firmar).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
command -v xcodegen >/dev/null || { echo "Falta xcodegen: brew install xcodegen" >&2; exit 1; }
xcodegen generate
for scheme in NovaWifiTag NovaWifiTagClip; do
  echo "▶ xcodebuild $scheme (iOS Simulator)"
  xcodebuild -project NovaWifiTag.xcodeproj -scheme "$scheme" \
    -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO \
    | grep -E 'error:|warning:|BUILD (SUCCEEDED|FAILED)' || true
done
