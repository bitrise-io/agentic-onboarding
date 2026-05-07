---
name: bitrise-onboard-end-to-end
description: >
  Run the full Bitrise prospect onboarding journey end-to-end in a single
  session: sign up for a Bitrise account, register an app and run a first
  CI build, then publish a public install page via Release Management.
  Use this whenever the user expresses intent for a complete Bitrise
  evaluation — e.g., "onboard me to Bitrise", "I want to try Bitrise from
  scratch", "set me up on Bitrise end to end", "walk me through Bitrise",
  "give me the full Bitrise demo", "I want to go from zero to a shareable
  install link". Prefer this skill over the individual stage skills when
  the user signals they want the whole journey, not just one piece.
---

# Bitrise End-to-End Onboarding (Orchestrator)

Drive the full Bitrise prospect journey in one session by orchestrating
three sub-skills in order:

1. **`bitrise-signup`** — anonymous registration via the MCP, ending with
   a Bitrise PAT installed in the user's MCP config.
2. **`bitrise-ci-onboarding`** — register the user's app in Bitrise CI,
   connect the repo, set up signing credentials, trigger and watch the
   first build.
3. **`bitrise-release-management`** — register the app in Release
   Management, upload the build artifact, surface the public install page
   URL.

Each sub-skill works on its own. This skill is the connective tissue: it
gathers shared context once, runs the stages in sequence, and hands state
between them so the prospect doesn't have to repeat themselves.

## Why this exists

The prospect wants one outcome: "I went from no account to a shareable
install link." Composing three skills sequentially keeps each stage
focused and testable, while this orchestrator hides the seam between
them. Without it, the user would have to manually invoke each skill and
repeat workspace slugs and app slugs across them.

## Preconditions

- The user has the Bitrise MCP installed from the `agentic-onboarding`
  branch. The hosted endpoint at `https://mcp.bitrise.io` doesn't yet have
  the signup or signing-upload tools. If the user is on the hosted
  version, route them to local stdio install first:
  `claude mcp add bitrise -- go run github.com/bitrise-io/bitrise-mcp/v2@agentic-onboarding`.
  No `BITRISE_TOKEN` needed at startup; the signup flow installs one.
- The user is willing to do all three stages in one session. If they only
  want one stage, run that sub-skill directly.

## Up-front context gathering

Before kicking off stage one, ask the user a few questions in one batch
so the rest of the flow runs without interruptions. Don't ask them again
later unless the answers don't apply.

1. **Email** for the Bitrise account (will receive an OTP).
2. **Platform**: iOS or Android (or Flutter / React Native — those route
   to platform-specific configs in stage 2).
3. **Repo URL**, public or private.
4. **Git provider** (GitHub, GitLab, Bitbucket, or self-hosted).
5. **Default branch name** (usually `main`).
6. **Bundle ID / package name** (you'll need this for stage 3; ask once,
   not three times).
7. **App display name** (also for stage 3).
8. **Path to a signing artifact**, if they have one ready: `.p12` +
   `.mobileprovision` for iOS, or `.jks`/`.keystore` + alias + passwords
   for Android. If they don't have these and just want to see a green
   build, skip signing in stage 2 — the default Android config uses the
   debug keystore, and iOS can build & test without distribution signing.

Maintain these in a context dictionary you carry across the stages:

```
{
  email, platform, repo_url, is_public, provider, default_branch,
  bundle_id, store_app_name, signing_files: {...},
  // populated as we go:
  workspace_slug, api_token, app_slug, build_slug,
  connected_app_id, installable_artifact_id, public_install_url
}
```

Don't put `api_token` in any chat output. Hold it during the config
update in stage 1, then drop it.

## Stage 1: Signup

Run the `bitrise-signup` skill. Pass the email. When done, capture:

- `workspace_slug` (from `verify_registration` or `list_workspaces`)
- The PAT is installed in the MCP config — it's not in your context any
  more, by design

Confirm with `me` and `list_workspaces` before moving on. If signup fails
(invalid email, expired OTP, MCP not reconnected), don't proceed to stage
2 — fix or stop.

## Stage 2: CI onboarding and first build

Run the `bitrise-ci-onboarding` skill. Pass:

- `workspace_slug` from stage 1
- `platform`, `repo_url`, `is_public`, `provider`, `default_branch`,
  `signing_files`

Capture:

- `app_slug`
- `build_slug` of the first successful build

If the build fails, stop and surface the failure log with diagnosis. Don't
roll into Release Management on a failed build — there's no artifact to
publish.

## Stage 3: Release Management public install page

Run the `bitrise-release-management` skill. Pass:

- `workspace_slug`
- `app_slug`
- `platform`
- `bundle_id` as `store_app_id`
- `store_app_name`
- `build_slug` (so the skill can pull the artifact from CI) OR a local
  artifact path if the user has one handy

Capture:

- `connected_app_id`
- `installable_artifact_id`
- The public install page URL

## Final hand-off

When all three stages succeed, summarize for the user:

- Their account email + workspace slug
- Their app's Bitrise URL (`https://app.bitrise.io/app/<app_slug>`)
- The build URL of their first green build
- The public install page URL

Suggest a couple of natural next steps: invite teammates to the workspace
(`invite_member_to_workspace`), set up Slack/email notifications, or send
the install URL to a tester. Keep the suggestion short — the prospect
just sat through three stages, give them air.

## Failure recovery

Each stage has its own failure modes. The orchestrator's job is to fail
loudly and helpfully:

- **Signup failure:** Don't continue. Tell the user what went wrong
  (invalid email, OTP expired, MCP not reconnected) and how to retry.
- **CI failure:** If `register_app` errored, fix the input and retry. If
  the first build failed, surface the failing step and don't move to
  stage 3. The build can be retried after a fix without redoing stage 1.
- **Release Management failure:** If processing fails (signing issue),
  stop and tell the user. Don't loop. The connected app and uploaded
  artifact persist, so a re-run from stage 3 with a fresh artifact can
  succeed without redoing 1 or 2.

## Things to watch out for

- **Don't ask the same question twice.** The whole point of this skill is
  reusing context across stages. If you find yourself asking about the
  workspace slug in stage 3 after capturing it in stage 1, something's
  off.
- **The PAT is installed in the MCP config, not in your context.** After
  stage 1, you don't have the token any more — and that's correct. All
  subsequent tool calls authenticate via the MCP transport.
- **Stage 1 requires a client reconnect.** This is the one place where
  the user has to do something outside the chat (restart Claude or
  re-establish the MCP connection). Set the expectation up-front so it's
  not a surprise.
- **A "demo" first build often doesn't need signing.** If the user just
  wants to see the journey work, skip signing in stage 2 and run a
  test/build workflow. Save signing for when they're ready to ship a real
  artifact through Release Management.
- **Total time: usually 15–30 minutes**, dominated by the first build (5–
  15 min) and any user latency on email/OTP. Set this expectation
  up-front.
- **iOS install pages have a UDID gotcha.** A dev-signed IPA only installs
  on devices in the provisioning profile. Mention this when handing the
  install URL over.
