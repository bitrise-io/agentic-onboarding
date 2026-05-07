---
name: bitrise-signup
description: >
  Sign a brand-new prospect up to Bitrise from inside Claude using the Bitrise
  MCP server's anonymous registration tools. Use this whenever the user says
  things like "sign me up to Bitrise", "create my Bitrise account", "I want to
  try Bitrise", "start a Bitrise trial", or expresses interest in trying
  Bitrise but doesn't have an account yet. Also use as the first step when the
  user asks for end-to-end Bitrise onboarding. Do NOT use this skill if the
  user already has a Bitrise PAT configured — go straight to bitrise-ci-onboarding.
---

# Bitrise Signup

Walk a prospect from "no Bitrise account" to "MCP authenticated and ready to
build". The Bitrise MCP server's `agentic-onboarding` branch exposes two
tools that run anonymously (no PAT required), and this skill drives them.

## Why these instructions exist

Signup is special: it's the only flow where the MCP works without a PAT, and
it ends with the agent rewriting the user's MCP client config to install the
PAT it just received. That's a sharp edge — the rest of this skill is about
not slipping on it.

## Preconditions

Before you start, verify the user has a working install of the Bitrise MCP
**from the `agentic-onboarding` branch**. The hosted endpoint at
`https://mcp.bitrise.io` runs `main` and does not yet have these tools.

Two install options work:

- **Local stdio (recommended for the PoC):**
  `claude mcp add bitrise -- go run github.com/bitrise-io/bitrise-mcp/v2@agentic-onboarding`
  Note: `BITRISE_TOKEN` does NOT need to be set yet. The new code lets stdio
  start without a token; signup tools work anonymously, and the token is
  installed afterwards.
- **Local HTTP transport** pointed at a self-hosted build of the branch.
  Send no `Authorization` header; the registration group runs without one.

If the user is connected to the hosted `mcp.bitrise.io`, stop and tell them
the signup tools aren't deployed there yet and ask them to switch to a local
install of the branch. Don't try to call `register` against a server that
doesn't have it — you'll get a "tool not found" error and confuse the user.

If the user mentions they already have a Bitrise account and just need to
hook up the MCP, skip signup entirely and ask them for their existing PAT
(generated at `https://app.bitrise.io/me/account/security`). This skill is
for net-new accounts.

## The flow

### 1. Get the user's email

Ask the user which email address they want to register with. Don't assume
the email in the session metadata is the right one — they may want to use a
work email vs. a personal one. Confirm before sending.

### 2. Start signup

Call `register` with `{ "email": "<the email>" }`. The response is:

```json
{ "pending_signup_id": "<id>", "expires_at": "<iso8601>" }
```

A 6-digit OTP code is emailed to the user. Tell them to check their inbox
(including spam). Capture `pending_signup_id` — you'll need it next.

If the response is an error: surface the status and body to the user and
stop. Common cases: invalid email format (400), email already registered
(409 — the user may already have an account; offer to skip to PAT setup
instead). The error response is structured JSON like
`{"status": 409, ...body fields...}` — read the status field to branch.

### 3. Collect the OTP and verify

Ask the user to paste the OTP from the email. Then call:

`verify_registration` with `{ "pending_signup_id": "<from step 2>", "otp": "<6-digit code>" }`.

The response is:

```json
{
  "user_slug": "<slug>",
  "api_token": "<pat>",
  "token_expires_at": "<iso8601>",
  "workspace_slug": "<slug or omitted>"
}
```

The `api_token` is a real, live Bitrise Personal Access Token. Treat it as a
secret. Do NOT echo it back in a chat message, do NOT log it, do NOT save it
to a file the user can see. Hold it just long enough to install it (next
step), then drop it from anything you write down.

If the OTP is wrong or expired, the response is an error with the appropriate
status. Offer to re-send by calling `register` again with the same email.

### 4. Install the PAT into the MCP client

This is the only step that needs you to leave the MCP and edit
configuration. Two cases:

**Stdio mode (most likely for the PoC):**
The user's `claude mcp add` command needs the token in `BITRISE_TOKEN`. Tell
them you're going to remove and re-add the MCP server with the token wired
in. Then run, in the user's shell:

```
claude mcp remove bitrise
claude mcp add bitrise -e BITRISE_TOKEN=<api_token> -- go run github.com/bitrise-io/bitrise-mcp/v2@agentic-onboarding
```

**HTTP mode:**
Re-add with an `Authorization: Bearer <api_token>` header:

```
claude mcp remove bitrise
claude mcp add --transport http bitrise <url> -H "Authorization: Bearer <api_token>"
```

After the config update, the user must restart Claude (or otherwise
re-establish the MCP connection) for the new token to take effect. Tell them
this explicitly. Until they do, every tool except `register` /
`verify_registration` will fail with the auth error
`missing Bitrise authentication: ...`.

### 5. Verify auth, surface the workspace

Once the user confirms they've reconnected, call `me` and `list_workspaces`
to confirm the PAT works. Show the user:

- Their account email and user slug (from `me`)
- The workspace slug(s) returned by `list_workspaces` — for a fresh signup
  there will be exactly one, auto-created during registration

This confirms signup worked end-to-end and gives the user (and the next
skill) the workspace slug they'll need.

## Hand-off to the next step

After this skill finishes, the prospect has:

- A Bitrise account (free 30-day Teams trial with 500 build credits — the
  default for new signups)
- A working PAT installed in their MCP client
- A workspace slug

If the user invoked this skill as part of an end-to-end onboarding flow,
hand off to `bitrise-ci-onboarding` and pass the workspace slug along.

## Things to watch out for

- **Don't paste the PAT into chat.** It's tempting to "show" the user what
  was generated. Don't. The user can read it back from their MCP config if
  they need to.
- **OTPs expire.** The `expires_at` field on the `register` response tells
  you when. If the user takes a long time to check email, the verify call
  may fail — re-run `register` to get a fresh OTP.
- **Don't pre-fill an email you scraped from the session metadata.** Always
  ask. The session email may be a work address the user doesn't want
  associated with a personal Bitrise trial, or vice versa.
- **The `workspace_slug` on the verify response can be omitted.** If it's
  missing, fall back to `list_workspaces` after the PAT is installed.
- **Don't assume HTTP vs. stdio.** Ask which transport the user installed.
  `claude mcp list` will show it; offer to run that for them if they're
  unsure.
