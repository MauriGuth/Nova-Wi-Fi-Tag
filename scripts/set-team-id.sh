#!/usr/bin/env bash
# Reemplaza el placeholder TEAMID por tu Team ID de Apple Developer en:
#   project.yml, ExportOptions.plist y web/.well-known/apple-app-site-association
# Uso: scripts/set-team-id.sh ABCDE12345
set -euo pipefail
TEAM="${1:?Uso: $0 <TEAM_ID de 10 caracteres, ej. ABCDE12345>}"
if [[ ! "$TEAM" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "Team ID inválido: '$TEAM' (son 10 caracteres alfanuméricos en mayúscula)" >&2
  exit 1
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for file in project.yml ExportOptions.plist web/.well-known/apple-app-site-association; do
  perl -pi -e "s/\bTEAMID\b/$TEAM/g" "$ROOT/$file"
  echo "✔ $file"
done
echo
echo "Listo. Ahora:"
echo "  1. xcodegen generate                      (regenera el proyecto con el Team ID)"
echo "  2. cd web && npx vercel --prod            (vuelve a publicar el AASA con el Team ID real)"
