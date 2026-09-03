#!/usr/bin/env bash
# Cambia el Team ID de Apple Developer en:
#   project.yml (DEVELOPMENT_TEAM), ExportOptions.plist (teamID) y web/.well-known/apple-app-site-association
# Uso: scripts/set-team-id.sh ABCDE12345
set -euo pipefail
NEW="${1:?Uso: $0 <TEAM_ID de 10 caracteres, ej. ABCDE12345>}"
if [[ ! "$NEW" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "Team ID inválido: '$NEW' (son 10 caracteres alfanuméricos en mayúscula)" >&2
  exit 1
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# El valor actual se lee de project.yml (la primera vez es el placeholder TEAMID).
CURRENT="$(perl -ne 'print $1 and exit if /^\s*DEVELOPMENT_TEAM:\s*(\S+)/' "$ROOT/project.yml")"
if [[ -z "$CURRENT" ]]; then
  echo "No encontré DEVELOPMENT_TEAM en project.yml" >&2
  exit 1
fi
if [[ "$CURRENT" == "$NEW" ]]; then
  echo "El Team ID ya es $NEW; nada que cambiar."
  exit 0
fi
for file in project.yml ExportOptions.plist web/.well-known/apple-app-site-association; do
  perl -pi -e "s/\b\Q$CURRENT\E\b/$NEW/g" "$ROOT/$file"
  echo "✔ $file  ($CURRENT → $NEW)"
done
echo
echo "Listo. Ahora:"
echo "  1. xcodegen generate                      (regenera el proyecto con el Team ID)"
echo "  2. cd web && npx vercel --prod            (vuelve a publicar el AASA con el Team ID nuevo)"
