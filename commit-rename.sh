#!/usr/bin/env bash
# Commit the rename + README rewrite and push to origin.
# Also cleans up sandbox debris (old .plugin file, the previous bootstrap script).

set -euo pipefail

cd "$(dirname "$0")"

echo "==> Cleaning up old artifacts..."
rm -f bitrise-onboarding-poc.plugin
rm -f setup-git.sh

echo "==> Staging changes..."
git add -A
git status --short

echo "==> Committing..."
git commit -m "Rename plugin to bitrise-agentic-onboarding; rewrite README

- plugin.json: rename to bitrise-agentic-onboarding, add homepage and
  repository fields pointing at the GitHub repo
- README: lead with the Claude Code CLI install path (claude plugin add)
  and git clone instructions instead of the Cowork drag-and-drop path
  (which Cowork desktop doesn't support today)
- README: add an explicit Cowork section explaining the gap
- README: add a 'Building a .plugin archive' section for the future
  install-from-file flow
- Drop the old bitrise-onboarding-poc.plugin build artifact (it's
  gitignored anyway, but keeping it lying around with a stale name was
  confusing)"

echo "==> Pushing..."
git push

echo
echo "==> Done. Commit pushed."
echo "==> You can delete this script: rm commit-rename.sh"
