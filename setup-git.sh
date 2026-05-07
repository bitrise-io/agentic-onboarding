#!/usr/bin/env bash
# One-shot git init for bitrise-io/agentic-onboarding.
# Cleans up debris that the Cowork sandbox left behind (it can't unlink
# files on the fuse mount), then inits, commits, and pushes.
#
# Run from inside ~/Development/Bitrise/bitrise-agentic-onboarding.

set -euo pipefail

cd "$(dirname "$0")"

echo "==> Cleaning up sandbox debris..."
rm -rf .git .git-broken
rm -f test-file

echo "==> Initialising git repo..."
git init -b main
git config user.email "antal.orcsik@bitrise.io"
git config user.name "Antal Orcsik"

echo "==> Staging files..."
git add -A
git status --short

echo "==> Creating initial commit..."
git commit -m "Initial commit: Bitrise agentic-onboarding skills (PoC)

Four skills + .mcp.json that auto-wires the agentic-onboarding branch of
github.com/bitrise-io/bitrise-mcp:

- bitrise-signup: anonymous register / verify_registration, installs PAT
- bitrise-ci-onboarding: register_app, code signing, first build
- bitrise-release-management: connected app, public install page
- bitrise-onboard-end-to-end: orchestrator chaining all three"

echo "==> Setting remote and pushing..."
git remote add origin https://github.com/bitrise-io/agentic-onboarding.git
git push -u origin main

echo
echo "==> Done. Repo pushed to https://github.com/bitrise-io/agentic-onboarding"
echo "==> You can delete this script now: rm setup-git.sh"
