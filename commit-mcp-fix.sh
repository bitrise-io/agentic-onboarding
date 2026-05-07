#!/usr/bin/env bash
# Commit the MCP-config inlining and push.
# Removes the now-obsolete .mcp.json (the sandbox can't unlink files on the
# fuse mount, hence this script for the host).

set -euo pipefail

cd "$(dirname "$0")"

echo "==> Removing obsolete .mcp.json (config now lives in plugin.json)..."
rm -f plugins/bitrise-agentic-onboarding/.mcp.json

echo "==> Cleaning up earlier bootstrap scripts..."
rm -f setup-git.sh commit-rename.sh commit-restructure.sh

echo "==> Staging changes..."
git add -A
git status --short

echo "==> Committing..."
git commit -m "Inline MCP config into plugin.json

The separate .mcp.json at the plugin root wasn't being auto-discovered
after install — likely because dotfiles aren't reliably copied into the
plugin cache. Moving the mcpServers block into plugin.json makes the MCP
declaration explicit and survives any copy/discovery quirks.

- plugins/bitrise-agentic-onboarding/.claude-plugin/plugin.json: add
  mcpServers
- plugins/bitrise-agentic-onboarding/.mcp.json: deleted
- README: update references; drop .mcp.json from the layout diagram"

echo "==> Pushing..."
git push

echo
echo "==> Done. Now reinstall to test:"
echo "    claude plugin uninstall bitrise-agentic-onboarding@agentic-onboarding"
echo "    claude plugin marketplace update agentic-onboarding"
echo "    claude plugin install bitrise-agentic-onboarding@agentic-onboarding"
echo "    # restart claude, then /mcp"
echo
echo "==> You can delete this script: rm commit-mcp-fix.sh"
