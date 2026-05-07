# Bitrise Agentic Onboarding (PoC)

A Claude plugin that walks a brand-new Bitrise prospect from "no account" to
"shareable public install page" using the `agentic-onboarding` branch of the
Bitrise MCP server.

> **Status:** proof of concept. The signup, code-signing, and provider-OAuth
> tools the skills depend on live on the `agentic-onboarding` branch of
> [bitrise-io/bitrise-mcp](https://github.com/bitrise-io/bitrise-mcp), which
> isn't deployed to the hosted MCP endpoint yet. Until it is, the plugin
> auto-wires the MCP via local `go run` against that branch.

## What's in the plugin

Four skills:

| Skill | Triggers on | What it does |
|---|---|---|
| `bitrise-signup` | "sign me up to Bitrise", "create my Bitrise account" | Anonymous `register` + `verify_registration`, installs the returned PAT into the MCP config |
| `bitrise-ci-onboarding` | "set up my project on Bitrise", "run my first build" | Register app → repo OAuth → SSH key → stack pick → signing upload → trigger build → watch logs |
| `bitrise-release-management` | "share my build", "get a public install link" | Connected app → signed-URL upload → enable public install page → surface URL |
| `bitrise-onboard-end-to-end` | "onboard me to Bitrise from scratch", "give me the full demo" | Orchestrator that runs all three with shared state |

Plus an `.mcp.json` at the repo root that auto-wires the Bitrise MCP from
the `agentic-onboarding` branch via `go run`.

## Requirements

- **Go ≥ 1.25** on your machine. The MCP is a Go binary that gets compiled
  on first launch via `go run`. Check with `go version`; install from
  <https://go.dev/dl/> if missing.
- **Claude Code CLI** (recommended), or any Claude client that supports
  installing plugins from a local path. Cowork desktop's plugin-from-file
  install isn't supported yet — see the *Cowork* section below.
- An internet connection on first run (Go pulls the branch from
  `proxy.golang.org`).

## Install (Claude Code CLI)

```bash
# Clone (or use this repo if you already have it)
git clone https://github.com/bitrise-io/agentic-onboarding.git
cd agentic-onboarding

# Register the plugin with Claude Code
claude plugin add .
```

Then start Claude:

```bash
claude
```

In the chat, try:

> Onboard me to Bitrise from scratch.

That fires the `bitrise-onboard-end-to-end` orchestrator. Or trigger an
individual stage with phrasings like *"sign me up to Bitrise"*, *"set up my
project on Bitrise CI"*, *"get me a public install link for my build"*.

The first time the MCP runs, `go run` fetches and compiles the
`agentic-onboarding` branch — that takes ~30–90 seconds and looks like
silence. Subsequent runs reuse Go's compiled-binary cache and start in
under a second.

## Cowork desktop

Cowork's plugin install today goes through marketplaces, not local files.
Dragging a `.plugin` archive into chat just uploads it as an attachment;
it doesn't install. Once Cowork supports local plugin install (or this
plugin is published to a marketplace), the same source works there
unchanged. For now, run the skills via Claude Code CLI as above.

## How auth works

- The MCP starts with no `BITRISE_TOKEN`. That's deliberate — the signup
  tools (`register` / `verify_registration`) run anonymously and need no
  credential.
- After signup, the orchestrator hands you the new PAT and updates the MCP
  config. You restart your Claude client once; from then on, every other
  tool call authenticates via that PAT.
- The PAT is never echoed back into chat. It lives in the MCP client config
  only.

## Why the `agentic-onboarding` branch

The signup tools, certificate/keystore upload tools, and provider OAuth
helpers only exist on that branch. `main` (and the hosted
`mcp.bitrise.io` endpoint that runs `main`) would fail on the very first
call — `register` isn't a registered tool there.

Once the branch lands on `main` and ships to the hosted endpoint, this
plugin's `.mcp.json` can be flipped to:

```json
{
  "mcpServers": {
    "bitrise": {
      "url": "https://mcp.bitrise.io"
    }
  }
}
```

and skip the local `go run` entirely.

## Known gaps

- **Public install page URL field.** The skill inspects whatever URL field
  `list_installable_artifacts` returns. If the response shape changes, the
  skill surfaces a "look in the web UI" fallback rather than fabricate a
  URL. First time the flow runs against a real artifact, it's worth
  capturing the actual response shape so we can tighten the extraction.
- **CI artifact → Release Management promotion.** No MCP tool promotes a
  CI build's artifact directly to RM. The skill downloads from CI then
  re-uploads via the signed URL flow. Correct but slow.
- **iOS automatic provisioning.** The workspace-level Apple API key flow
  is web-only. The skill points the prospect at the Bitrise web UI when
  that path is right.

## Repo layout

```
.
├── .claude-plugin/plugin.json   Plugin manifest
├── .mcp.json                    Auto-wires the Bitrise MCP from the branch
├── skills/
│   ├── bitrise-signup/
│   ├── bitrise-ci-onboarding/
│   ├── bitrise-release-management/
│   └── bitrise-onboard-end-to-end/
└── README.md
```

## Building a `.plugin` archive (optional)

If you want a portable `.plugin` zip for future install-from-file flows:

```bash
cd /path/to/agentic-onboarding
zip -r /tmp/bitrise-agentic-onboarding.plugin . -x "*.DS_Store" ".git/*"
```

The archive is gitignored — don't commit it.

## Uninstalling

```bash
claude plugin remove bitrise-agentic-onboarding
```

The Go module cache (the compiled MCP binary) stays in `$GOPATH/pkg/mod`;
run `go clean -modcache` if you want it gone.
