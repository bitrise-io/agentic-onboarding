---
name: bitrise-ci-onboarding
description: >
  Take a Bitrise prospect from "I have an account" to "my first build is
  green" by registering a project, connecting a repo, uploading signing
  credentials, and triggering the first build via the Bitrise MCP server.
  Use this when the user asks to "set up my project on Bitrise", "connect my
  repo to Bitrise", "run my first Bitrise build", "onboard my app to
  Bitrise CI", or "get my iOS/Android app building on Bitrise". The user
  must already have a Bitrise PAT wired into the MCP — if they don't, run
  bitrise-signup first. Use this skill regardless of whether it's iOS or
  Android; the skill branches internally.
---

# Bitrise CI Onboarding

Drive a prospect through the full first-build flow: app registration →
repository connection → signing credentials → trigger build → watch it go
green. This is the second of three skills in the prospect onboarding
journey.

## Why these instructions exist

The CI onboarding flow has more moving parts than signup, and the parts
have an order: you can't trigger a build before the app is finished, you
can't sign without the credential uploaded, and you can't push to a private
repo without the SSH key registered. This skill is the recipe.

It also branches by platform (iOS vs. Android) at two points: project
config selection and credential upload. Read the platform-specific section
for the user's platform; ignore the other.

## Preconditions

- The user must have a working Bitrise PAT in the MCP. Sanity-check by
  calling `me` first — if it errors, route the user to `bitrise-signup`.
- The user must be on the `agentic-onboarding` branch's MCP for the
  signing-upload tools (`upload_build_certificate`,
  `upload_provisioning_profile`, `upload_android_keystore_file`) to be
  available. The hosted `mcp.bitrise.io` does not have these yet. If the
  signing tools error with "tool not found", fall back to the manual web
  upload — see "Fallback: web-based credential upload" below.

## The flow

### 1. Confirm context: workspace, platform, repo

Before calling any tools, gather four things by asking the user:

- **Workspace.** Call `list_workspaces`. If there's exactly one, use it. If
  there are several, present the list and ask the user to pick. Capture the
  `workspace_slug`.
- **Platform.** iOS or Android? This decides the project config and the
  signing flow.
- **Repository URL.** Confirm the full URL (e.g.,
  `https://github.com/acme/cool-app.git`). Confirm whether it's public or
  private — private repos need SSH key registration.
- **Git provider.** GitHub, GitLab, Bitbucket, or self-hosted variants?
  Defaults to `github` if unsure but ask.

If the user hasn't connected the provider's account to Bitrise yet, call
`get_provider_connect_url` with the chosen provider. Open the returned URL
in their browser, ask them to complete the OAuth flow, then poll
`list_connected_accounts` until the provider shows as connected. Don't move
on until it is.

### 2. Register the app

Call `register_app` with:

- `repo_url`: as confirmed above
- `is_public`: boolean from the user's answer
- `organization_slug`: the workspace slug
- `provider`: e.g., `github`
- `default_branch_name`: ask the user; default to `main`. (The MCP defaults
  to `master`, which is wrong for most modern repos.)

Capture the returned `app_slug`. The MCP description says not to prompt for
finishing the app — chain straight into the next step.

### 3. Register the SSH key (private repos only)

For a private repo, build won't be able to clone without an SSH key. The
prospect probably doesn't have one ready. Two options:

- **Have the MCP generate one for them.** Generate an ed25519 keypair on
  the user's machine via shell:
  `ssh-keygen -t ed25519 -f bitrise_deploy_key -N "" -C "bitrise-<app-slug>"`.
  Read both files. Then call `register_ssh_key` with `app_slug`,
  `auth_ssh_private_key`, `auth_ssh_public_key`, and
  `is_register_key_into_provider_service: true` so Bitrise auto-registers
  the public key as a deploy key on GitHub/GitLab/Bitbucket. Delete the
  local keypair files after — they're only needed for the upload.
- **Have the user paste an existing key.** If they already have a deploy
  key, ask for both halves. Same `register_ssh_key` call, but set
  `is_register_key_into_provider_service: false`.

For a public repo, skip this step.

### 4. Pick a stack and finish setup

Call `list_available_stacks` (pass `workspace_slug` to include workspace
custom stacks). Pick a sensible default for the platform — for iOS, the
latest macOS stack; for Android, the latest `linux-docker-android-22.04` or
similar. Tell the user which stack you picked and why; let them override.

Then call `finish_bitrise_app` with:

- `app_slug`: from step 2
- `project_type`: `ios` or `android` (or `flutter`, `react-native`, etc. if
  the user said so)
- `stack_id`: from above
- `config`: a starter config that matches the project type. Common values:
  `default-ios-config`, `default-android-config-kts`,
  `default-flutter-config-android`, `default-react-native-config`, etc.

Per the MCP tool description, don't prompt the user before this call —
just run it.

### 5. Register a webhook

Call `register_webhook` with `app_slug`. This makes git pushes auto-trigger
builds, which is what the user expects from CI. Skip if the user
explicitly asked for manual-only triggering.

### 6. Set up signing credentials

This is where the flow forks by platform. **For the very first build**,
consider whether signing is even needed yet. The default starter configs
build & test on every push but don't always require distribution signing.
If the user just wants to see a green build, you can skip this step on the
first run and circle back when they want to ship to TestFlight / Play
Console / Release Management.

If signing IS needed:

#### iOS

Two files must be uploaded: a `.p12` build certificate and a
`.mobileprovision` provisioning profile. Ask the user where on disk both
files live. The MCP reads them from the local filesystem (the `file_path`
arg is read with `os.ReadFile`), so the files must be reachable to whatever
process the MCP runs as — practically, the user's machine.

- `upload_build_certificate` with `app_slug`, `file_path` (absolute path to
  `.p12`), and `certificate_password` if the cert is password-protected.
  Returns the API response; capture `data.slug` if you want to chain
  updates.
- `upload_provisioning_profile` with `app_slug`, `file_path` (absolute path
  to `.mobileprovision`).

If the user doesn't have a build certificate or provisioning profile yet,
walk them through generating them in Xcode → Apple Developer portal, or
suggest the workspace-level "Apple API key" automatic provisioning flow
(set up in the Bitrise web UI at workspace settings; the MCP doesn't expose
it). Don't fabricate certs.

#### Android

A keystore (`.jks` or `.keystore`) plus its alias and two passwords:

- `upload_android_keystore_file` with `app_slug`, `file_path` (absolute
  path to keystore), `alias`, `keystore_password`, `private_key_password`.
  All five are required.

If the user doesn't have a keystore yet and just wants a green build, the
default Android config will use the auto-generated debug keystore, which
ships with the Android SDK. Skip the upload and only set up a release
keystore when the user is ready to publish.

#### Fallback: web-based credential upload

If the MCP signing tools aren't available (e.g., user's on the hosted
`mcp.bitrise.io`), point them at the Code Signing tab of the Workflow
Editor:
`https://app.bitrise.io/app/<app_slug>/workflow_editor#code-signing`. The
upload UI there is the same flow, just in a browser. Don't pretend the
tools work and then fail.

### 7. Trigger the first build

Call `trigger_bitrise_build`:

- `app_slug`: from step 2
- `branch`: the default branch the user confirmed (`main`, usually)
- `workflow_id`: leave empty to use the config's default workflow
  (typically `primary` or `deploy`), or pass one explicitly if the user has
  a preference

Capture the returned `build_slug` and `build_url`. Share `build_url` with
the user immediately so they can watch in the browser if they want.

### 8. Wait for the build

Poll `get_build` with `build_slug` until the `status` field changes from 0
(not finished) to 1 (success), 2 (failed), or 3 (aborted). Status code 4
means in-progress. Reasonable polling cadence: every 10–15 seconds for the
first minute, then every 30 seconds. Tell the user roughly how long mobile
builds take (5–15 minutes is typical) so they don't think it's hung.

If the build succeeds: report the build URL, the duration, and offer to
move on to Release Management (`bitrise-release-management`) if they want
a public install page.

If the build fails: call `get_build_log` with `build_slug` and read the
log. Look for the failing step. Common first-build failures and how to
respond:

- **Clone failure on a private repo:** SSH key not registered or not
  authorized at the provider. Re-run step 3 and confirm the deploy key
  shows up at github.com/<repo>/settings/keys.
- **Code signing error on iOS:** Provisioning profile mismatch or wrong
  bundle ID. Surface the error message to the user and suggest the
  automatic provisioning flow.
- **Stack mismatch:** Build expects an Xcode/Java version not on the
  chosen stack. Re-run `finish_bitrise_app` with a different `stack_id`,
  or edit the bitrise.yml directly via `get_bitrise_yml` →
  `update_bitrise_yml`.

Don't paper over a failed first build — the user wants to know what's
wrong, not be told everything's fine.

## Hand-off to Release Management

When the build is green and the user wants a public install page, call
`bitrise-release-management` and pass:

- `workspace_slug`
- `app_slug`
- `platform`
- `build_slug` (latest successful build)
- The bundle ID (iOS) or package name (Android) — the user will know this
  or you can extract it from the build artifact

## Things to watch out for

- **The MCP's `register_app` defaults `default_branch_name` to `master`.**
  Almost always wrong now — ask the user.
- **`finish_bitrise_app` is mandatory.** A `register_app`'d app without
  `finish_bitrise_app` is in a half-configured state and won't build. The
  MCP description tells the agent to chain immediately.
- **Tool description for `register_app` says "always prompt the user to
  choose which workspace if they have multiple".** Honor this — don't
  silently pick the first one.
- **Build status codes:** 0=not finished (queued), 1=success, 2=failed,
  3=aborted, 4=in-progress. Don't conflate "not finished" with "failed".
- **Don't put PATs, keystores, or `.p12` contents into the chat.** All of
  these are secrets. Reference them by file path or by Bitrise slug.
- **The signing-upload tools read files from local disk.** They only work
  in stdio mode (or against an MCP server with access to the same
  filesystem as the file). HTTP-hosted MCPs can't read the user's local
  disk; in that case use the web fallback.
