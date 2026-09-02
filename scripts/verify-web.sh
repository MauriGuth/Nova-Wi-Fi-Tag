#!/usr/bin/env bash
# Verifica que el backend estático responda como espera iOS.
# Uso: scripts/verify-web.sh [https://wifi.novasolutions.ar] [tagId]
set -uo pipefail
BASE="${1:-https://wifi.novasolutions.ar}"
TAG="${2:-casa}"
fail=0
check() {
  local path="$1" want_code="$2" want_type="$3"
  local out code type
  out=$(curl -sS -o /dev/null -w '%{http_code} %{content_type} %{redirect_url}' "$BASE$path" 2>&1) || { echo "✘ $path  (curl: $out)"; fail=1; return; }
  code=${out%% *}; type=$(echo "$out" | cut -d' ' -f2)
  if [[ "$code" == "$want_code" && "$type" == $want_type* ]]; then
    echo "✔ $path  → $out"
  else
    echo "✘ $path  → $out   (esperado: $want_code $want_type)"; fail=1
  fi
}
check "/.well-known/apple-app-site-association" 200 "application/json"
check "/api/tags/$TAG.json"                     200 "application/json"
check "/t/$TAG"                                 200 "text/html"
check "/t/$TAG/wifi.mobileconfig"               200 "application/x-apple-aspen-config"
check "/"                                       307 "text/plain"
echo "— AASA —"; curl -sS "$BASE/.well-known/apple-app-site-association"; echo
echo "— api —";  curl -sS "$BASE/api/tags/$TAG.json"; echo
exit $fail
