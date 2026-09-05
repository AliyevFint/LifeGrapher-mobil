#!/usr/bin/env zsh
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -n "$(git status --porcelain -- . ':(exclude)logs/*.log')" ]]; then
  # Runtime logs are evidence for troubleshooting, not source changes. Leaving
  # them out avoids empty daily commits caused solely by scheduler output.
  git add -A -- . ':(exclude)logs/*.log'
  git commit -m "chore: daily timeline update $(date +%Y-%m-%d)"
  git push
  echo "Changes committed and pushed."
else
  echo "No changes to commit."
fi
