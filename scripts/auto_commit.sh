#!/usr/bin/env zsh
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  git commit -m "chore: daily timeline update $(date +%Y-%m-%d)"
  git push
  echo "Changes committed and pushed."
else
  echo "No changes to commit."
fi
