---
name: bitrise-release-management
description: >
  Take a Bitrise prospect from "I have a working CI build" to "I have a
  shareable public install page link" by registering the app in Bitrise
  Release Management, uploading the installable artifact (IPA / APK / AAB),
  enabling the public install page, and surfacing the URL. Use this when the
  user asks to "share my build", "get an install link", "send a build to
  testers", "set up Release Management", "publish a beta", or "get a public
  install page". The user must already have a Bitrise account, an app
  registered in Bitrise CI, and at least one successful build with a
  distributable artifact. If they don't, route them to bitrise-signup or
  bitrise-ci-onboarding first.
---

# Bitrise Release Management Onboarding

Get a prospect's first installable build into Release Management and produce
a public install page URL they can share with testers or stakeholders. This
is the third of three skills in the prospect onboarding journey.

## Why these instructions exist

Release Management (RM) is conceptually separate from CI — a "connected
app" in RM is its own object with its own UUID, tied to a workspace and
optionally to a CI project. The artifact that lives on the CI side does
not automatically appear in RM; you have to upload it. This skill is the
recipe for that.

There's also one piece that the Bitrise MCP doesn't quite finish: the
exact response field that contains the rendered public install page URL
isn't documented. The skill calls `list_installable_artifacts` after
enabling the page and inspects whatever URL field comes back. If the
response shape differs from expectation, surface what's actually there —
don't fabricate a URL.

## Preconditions

- The user has a Bitrise PAT wired into the MCP. Run `me` to confirm.
- The user has a CI app and at least one successful build with a
  distributable artifact (`.ipa`, `.apk`, or `.aab`). If they don't, run
  `bitrise-ci-onboarding` first.
- The user knows their app's bundle ID (iOS) or package name (Android).
  Apple-style: `com.acme.coolapp`. Both platforms use a similar reverse-DNS
  format.
- For iOS public install pages with truly no Apple-side connection, use
  `manual_connection: true` (covered below). Otherwise, an App Store
  Connect / Google Play Console store credential needs to exist at the
  workspace level — that's a separate setup the prospect may not have done
  yet. For a PoC walkthrough, default to `manual_connection: true` so the
  flow doesn't require those credentials.

## The flow

### 1. Confirm context

Gather, by asking the user:

- **Workspace slug.** Reuse from `bitrise-ci-onboarding` if you ran it. If
  not, call `list_workspaces` and pick.
- **Platform.** `ios` or `android`. The store_app_id format and the artifact
  type (IPA vs APK/AAB) depend on this.
- **Bundle ID / package name.** This becomes `store_app_id` on the
  connected app. Confirm with the user — typos here mean the install page
  installs nothing.
- **App display name.** Required if you go with `manual_connection: true`.
- **The artifact.** Either (a) the slug of a successful CI build whose
  artifact you'll fetch, or (b) a path to a local IPA/APK/AAB on the user's
  disk. Path is simpler; build-slug requires extra work to download from CI
  first.

### 2. Create the connected app

Call `create_connected_app`:

- `platform`: `ios` or `android`
- `store_app_id`: bundle ID / package name
- `workspace_slug`: from step 1
- `manual_connection`: `true` (default for the PoC; bypasses App Store /
  Play credential requirements)
- `store_app_name`: required when `manual_connection` is true
- `project_id`: omit, and Bitrise auto-creates a new RM project. If the
  user has an existing RM project they want to attach to, pass its UUID.

Capture the returned `connected_app_id` (a UUIDv4). You'll need it for the
upload and for enabling the public install page.

### 3. Prepare the artifact

If the user gave a local file path, you're set — record `file_name` (the
basename), `file_size_bytes` (size on disk).

If the user pointed at a CI build slug, you need to fetch the artifact
first:

- `list_artifacts(app_slug, build_slug)` to find the artifact
- `get_artifact(app_slug, build_slug, artifact_slug)` to get the
  `expiring_download_url`
- Download it via shell (`curl`) to a known local path
- Then proceed as if the user gave you a local path

For iOS, look for `.ipa`. For Android, prefer `.aab` if available
(Play-friendly), fall back to `.apk`.

### 4. Generate the upload URL

Generate a fresh UUIDv4 client-side as `installable_artifact_id`. The
Python and Node MCPs both support this; if you can't generate one, ask the
user to provide one. This UUID becomes the artifact's identity in RM.

Call `generate_installable_artifact_upload_url`:

- `connected_app_id`: from step 2
- `installable_artifact_id`: the UUIDv4 you just generated
- `file_name`: e.g., `coolapp-v1.0.0.ipa`
- `file_size_bytes`: from step 3
- `branch`: optional; pass the branch the build came from if you know it
- `workflow`: optional; pass the workflow name if you know it
- `with_public_page`: `true` — turn on the public install page at upload
  time so you don't need a separate enable call later

The response gives `url`, `method`, and `headers`. Treat `headers` as a
dict; you must replay each one verbatim on the upload.

### 5. Upload the binary

The MCP doesn't have a tool for the actual byte transfer — you do this via
shell. Construct a `curl` command using `method`, `url`, and each header
from step 4. Example shape (substitute actual values):

```
curl -X PUT \
  -H "<header-key>: <header-value>" \
  -H "<header-key-2>: <header-value-2>" \
  --data-binary @<local-file-path> \
  "<upload-url>"
```

Run it with the workspace bash tool. Stream stdout/stderr to the user so
they see the upload happening. A failed upload (non-2xx) means the URL
expired or a header was wrong; regenerate via step 4.

### 6. Wait for processing

Bitrise needs to validate the artifact (check signing, parse metadata)
before it can be served from a public install page. Poll
`get_installable_artifact_upload_and_processing_status`:

- `connected_app_id`
- `installable_artifact_id`

Until the status indicates processed/ready (the exact field varies; treat
"not failed and no longer pending" as ready). Reasonable cadence: every 5
seconds for the first minute, then every 15 seconds. If the response
indicates a failure status, surface the message and stop — usually it's a
signing issue with the artifact.

### 7. Confirm the public install page is on

If you passed `with_public_page: true` at step 4, this should already be
on. As a defensive check, call `set_installable_artifact_public_install_page`:

- `connected_app_id`
- `installable_artifact_id`
- `with_public_page: true`

This requires Project Admin / Workspace Admin / Project Owner role. The
prospect's auto-created workspace makes them owner, so this should work,
but the tool description warns that lower-role users get an error. If you
hit that error, tell the user they don't have the role to enable public
install pages and stop.

### 8. Get the URL and share it

Call `list_installable_artifacts` filtered by `connected_app_id`. The
response includes per-artifact metadata, including (typically) a public
URL field. The exact field name isn't documented — read the response
carefully and surface whatever URL field is there. Look for fields like
`public_install_page_url`, `public_url`, `install_page_url`, or a nested
object representing the public page.

Show the user the URL with a one-liner about what they can do with it
(open on a phone, send to testers, etc.). Note that iOS install pages need
the device's UDID to be in a provisioning profile that signed the build —
if the build is dev-signed, only registered devices can install. Mention
this if the platform is iOS.

If you cannot find a URL in the response, say so plainly: "I created the
artifact and enabled the public page, but I can't find the URL in the
API response. You can find it in the Bitrise web UI under Release
Management → <app name> → Releases." Don't make one up.

### 9. (Optional) Add tester groups

If the user wants to notify a group of testers rather than (or in addition
to) sharing a public link:

- `get_potential_testers` to see who's available in the workspace
- `create_tester_group` with name + member slugs
- `add_testers_to_tester_group` if more need to be added later
- `notify_tester_group` to send the email

Skip this entirely for the public-link-only flow.

## Things to watch out for

- **Manual vs. store-connected apps.** For a prospect with no App Store /
  Play credentials yet, always pass `manual_connection: true` and
  `store_app_name`. Don't try to fetch credentials they don't have.
- **The public install page URL is not documented.** Read the actual
  response from `list_installable_artifacts`. If you guess the field name
  and the SDK changes the shape, the user gets a 404 link.
- **iOS install pages and UDIDs.** A development-signed IPA can only be
  installed on devices listed in the provisioning profile. For broader
  distribution, the user needs an enterprise distribution profile or
  Ad-Hoc with the right UDIDs. Surface this constraint when handing the
  link over for iOS.
- **Don't paste PATs or signed URLs into chat.** The presigned upload URL
  contains a signature; treat it as short-lived secret. Use it once via
  shell, then drop it.
- **`installable_artifact_id` is client-generated.** Don't reuse one
  across artifacts; each upload needs its own UUIDv4.
- **Role check failures on the public-page enable call.** Tool description
  explicitly warns about this. If the user doesn't have the role, escalate
  to the workspace admin — don't try to retry.
