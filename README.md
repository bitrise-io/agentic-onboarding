# Bitrise Onboarding (PoC)

A Cowork plugin that walks a brand-new Bitrise prospect from "no account" to
"shareable public install page" using the `agentic-onboarding` branch of the
Bitrise MCP.

## What you get

Four skills:

- **bitrise-signup** — anonymous registration via the MCP (`register` /
  `verify_registration`); installs the resulting PAT into your MCP config.
- **bitrise-ci-onboarding** — register an app, hook up the repo, upload
  signing credentials, trigger and watch the first build.
- **bitrise-release-management** — register a connected app, upload an
  artifact with a public install page enabled, surface the URL.
- **bitrise-onboard-end-to-end** — orchestrator that runs all three with
  shared context.

Plus an `.mcp.json` that auto-wires the Bitrise MCP from the
`agentic-onboarding` branch via `go run`.

## Requirements

- **Go ≥ 1.25** on the user's machine (the MCP is a Go binary built on
  demand). Check with `go version`. Install from <https://go.dev/dl/> if
  needed.
- **Cowork (Claude desktop)**, recent enough to load plugin-bundled MCPs.
- A working internet connection on first run (Go will pull the module from
  `proxy.golang.org`).

## Install

1. Drag the `.plugin` file into Cowork (or use the plugin install flow).
2. Restart Cowork after installation so the MCP server starts up.
3. In a new chat, say something like "Onboard me to Bitrise from scratch"
   to trigger the orchestrator skill.

The first time the MCP runs, `go run` will fetch and compile the branch.
That can take 30–90 seconds. Subsequent runs are fast (Go caches the
compiled binary).

## How auth works

- The MCP starts with no `BITRISE_TOKEN`. That's intentional — the signup
  tools (`register` / `verify_registration`) work anonymously.
- After signup, the orchestrator skill asks you to install the returned
  PAT into the MCP config and reconnect. From then on, everything else
  authenticates via PAT.
- The PAT is never echoed in chat. It lives in the MCP config only.

## Why the `agentic-onboarding` branch

The signup tools and the certificate/keystore upload tools only exist on
that branch. The hosted endpoint at `https://mcp.bitrise.io` runs `main`
and would fail on the very first call (`register` would not be found).
Once the branch ships, this plugin can be updated to point at the hosted
URL and skip the local `go run`.

## Known gaps

- **Public install page URL field** — the skill inspects whatever URL
  field `list_installable_artifacts` returns. If the API response shape
  changes, the skill will surface a "look in the web UI" fallback rather
  than fabricate a URL.
- **CI artifact → Release Management promotion** — there's no MCP tool
  for direct promotion. The skill downloads from CI then re-uploads to
  RM via signed URL. Slow but correct.
- **iOS automatic provisioning** — the workspace-level Apple API key
  flow is web-only. The skill points at the web UI when relevant.

## Uninstalling

Remove the plugin from Cowork's plugin list. The Go module cache stays
behind in `$GOPATH/pkg/mod`; clean it with `go clean -modcache` if you
want it gone.
