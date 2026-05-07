#!/usr/bin/env bash
# Commit the marketplace restructure and push.
# Cleans up sandbox debris (the obsolete .plugin file and prior bootstrap
# scripts) along the way.

set -euo pipefail

cd "$(dirname "$0")"

echo "==> Cleaning up old artifacts..."
rm -f bitrise-agentic-onboarding.plugin
rm -f bitrise-onboarding-poc.plugin
rm -f setup-git.sh
rm -f commit-rename.sh

echo "==> Staging changes..."
git add -A
git status --short

echo "==> Committing..."
git commit -m "Restructure to marketplace layout

- Move plugin contents from repo root into plugins/bitrise-agentic-onboarding/
- Add .claude-plugin/marketplace.json at root, marketplace name 'agentic-onboarding'
- Update README to lead with the marketplace install commands:
    claude plugin marketplace add bitrise-io/agentic-onboarding
    claude plugin install bitrise-agentic-onboarding@agentic-onboarding
- Demote --plugin-dir to a 'local development' note
- Drop the bundled .plugin zip artifact (now obsolete with marketplace install)"

echo "==> Pushing..."
git push

echo
echo "==> Done. Marketplace is live at:"
echo "    https://github.com/bitrise-io/agentic-onboarding"
echo
echo "==> Test install:"
echo "    claude plugin marketplace add bitrise-io/agentic-onboarding"
echo "    claude plugin install bitrise-agentic-onboarding@agentic-onboarding"
echo
echo "==> You can delete this script: rm commit-restructure.sh"
