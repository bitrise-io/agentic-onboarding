# Bitrise Agentic Onboarding (PoC)

A Claude Code plugin marketplace that walks a brand-new Bitrise prospect
from "no account" to "shareable public install page" using the
`agentic-onboarding` branch of the Bitrise MCP server.

> **Status:** proof of concept. The signup, code-signing, and provider-OAuth
> tools the skills depend on live on the `agentic-onboarding` branch of
> [bitrise-io/bitrise-mcp](https://github.com/bitrise-io/bitrise-mcp), which
> isn't deployed to the hosted MCP endpoint yet. Until it is, the plugin
> auto-wires the MCP via local `go run` against that branch.

## Quick install

Two commands in your terminal:

```bash
claude plugin marketplace add bitrise-io/agentic-onboarding
claude plugin install bitrise-agentic-onboarding@agentic-onboarding
```

Then start Claude and try:

```bash
claude
```

> Onboard me to Bitrise from scratch.

That fires the orchestrator, which runs you through signup → first build →
public install page. The first time the MCP runs, `go run` fetches and
compiles the `agentic-onboarding` branch — expect ~30–90 seconds of
silence, then it's fast on every subsequent launch.

## What's in the plugin

Four skills:

| Skill | Triggers on | What it does |
|---|---|---|
| `bitrise-signup` | "sign me up to Bitrise", "create my Bitrise account" | Anonymous `register` + `verify_registration`, installs the returned PAT into the MCP config |
| `bitrise-ci-onboarding` | "set up my project on Bitrise", "run my first build" | Register app → repo OAuth → SSH key → stack pick → signing upload → trigger build → watch logs |
| `bitrise-release-management` | "share my build", "get a public install link" | Connected app → signed-URL upload → enable public install page → surface URL |
| `bitrise-onboard-end-to-end` | "onboard me to Bitrise from scratch", "give me the full demo" | Orchestrator that runs all three with shared state |

Plus an `mcpServers` entry in the plugin manifest that auto-wires the
Bitrise MCP from the `agentic-onboarding` branch via `go run`.

## Requirements

- **Claude Code CLI.** Cowork desktop's local plugin install isn't
  supported yet — see the *Cowork* section below.
- **Go ≥ 1.25** on your machine. The MCP is a Go binary that compiles on
  first launch via `go run`. Check with `go version`; install from
  <https://go.dev/dl/> if missing.
- **Internet on first run** (Go pulls the branch from `proxy.golang.org`).

## How prospects experience it

1. Run the two install commands above. Two minutes, no credentials.
2. Start `claude`, type "onboard me to Bitrise from scratch".
3. The skill asks for an email; an OTP arrives by mail.
4. The skill installs a fresh Bitrise PAT into the MCP config; restart
   `claude` once.
5. Skill asks about the prospect's app — repo URL, platform, optional
   signing files — then registers it, triggers the first build, watches
   it go green.
6. Skill enables a Release Management public install page and hands back
   the URL.

Total time: ~15–30 minutes, dominated by the first build and email/OTP
latency. No browser detours required apart from one OAuth step for the
git provider.

## Cowork desktop

Cowork's local plugin install isn't supported in the current version.
This same marketplace will work in Cowork as soon as that ships; until
then, prospects use Claude Code CLI as above.

## How auth works

- The MCP starts with no `BITRISE_TOKEN`. That's deliberate — the signup
  tools (`register` / `verify_registration`) run anonymously and need no
  credential.
- After signup, the orchestrator hands you the new PAT and updates the MCP
  config. You restart your Claude client once; from then on, every other
  tool call authenticates via that PAT.
- The PAT is never echoed back into chat. It lives in the MCP client
  config only.

## Why the `agentic-onboarding` branch

The signup tools, certificate/keystore upload tools, and provider OAuth
helpers only exist on that branch. `main` (and the hosted
`mcp.bitrise.io` endpoint that runs `main`) would fail on the very first
call — `register` isn't a registered tool there.

Once the branch lands on `main` and ships to the hosted endpoint, this
plugin's `mcpServers` block in `plugin.json` can be flipped to:

```json
"mcpServers": {
  "bitrise": {
    "url": "https://mcp.bitrise.io"
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
├── .claude-plugin/marketplace.json     Marketplace catalog (one plugin)
├── plugins/
│   └── bitrise-agentic-onboarding/     The plugin itself
│       ├── .claude-plugin/plugin.json    Plugin manifest
│       └── skills/
│           ├── bitrise-signup/
│           ├── bitrise-ci-onboarding/
│           ├── bitrise-release-management/
│           └── bitrise-onboard-end-to-end/
└── README.md                           This file
```

## Local development

To work on the plugin without going through the marketplace install
cycle, point Claude Code at the plugin directory directly:

```bash
git clone https://github.com/bitrise-io/agentic-onboarding.git
cd agentic-onboarding
claude --plugin-dir ./plugins/bitrise-agentic-onboarding
```

Edit a `SKILL.md`, restart `claude`, and changes are picked up immediately.

To validate the marketplace + plugin manifests locally:

```bash
claude plugin validate .
```

## Updating

When new commits land on `main`, prospects can refresh:

```bash
claude plugin marketplace update agentic-onboarding
```

Or pin to a specific tag/branch via the marketplace add syntax:

```bash
claude plugin marketplace add bitrise-io/agentic-onboarding@v0.1.0
```

## Uninstalling

```bash
claude plugin uninstall bitrise-agentic-onboarding@agentic-onboarding
claude plugin marketplace remove agentic-onboarding
```

The Go module cache (the compiled MCP binary) stays in `$GOPATH/pkg/mod`;
run `go clean -modcache` if you want it gone.
