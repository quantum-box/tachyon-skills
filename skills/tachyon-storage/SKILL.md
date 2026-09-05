---
name: tachyon-storage
description: Integrate Tachyon Storage into Cloud Apps for file attachments, photos, uploads, downloads, and deletion; migrate direct R2 access or diagnose storage failures in previews and builds.
---

# Tachyon Storage

Use Tachyon-managed storage for app files without distributing Cloudflare credentials to the app. For new Tachyon app integrations, start with the Storage API flow below. Respect an explicitly chosen native binding or external storage design.

## Choose the Access Path

- **Storage API:** the app server authorizes the user, requests upload/download URLs from Tachyon, and stores the returned storage key. This works without a native R2 binding. Read [references/api-integration.md](references/api-integration.md) for the request contract and migration steps.
- **Managed R2 binding:** when an app intentionally uses `env.BUCKET`, inspect its manifest `r2Buckets` and the deployment target's support. Tachyon manages the bucket; this is also a Tachyon Storage integration. `bucketName` is a label, not necessarily the physical bucket name. Use resolved binding metadata or `{binding}_BUCKET_NAME`; do not create a same-named bucket with Wrangler. Verify the deployed binding before claiming it works on a particular target.

API access and native bindings are not interchangeable without checking the bucket and key mapping. The API's `upload-url` request has no `bucket` field; do not assume it writes to a Cloud App binding's bucket. For an existing managed bucket, verify authorization and use the explicit-bucket API described in the reference.

## Orient and Authenticate

1. Identify the app, API base URL, acting tenant/operator, preview or production environment, and existing storage adapter. Use the user's deployment metadata; do not copy another organization's IDs.
2. Inspect the installed SDK/API contract before choosing methods. Do not invent a `tachyon storage` CLI command. Use the sibling [tachyon-cli skill](../tachyon-cli/SKILL.md) for profile, app, and build inspection.
3. Use the app's supported server-side Tachyon authentication. Where Cloud App OAuth credentials are provisioned, resolve the issuer/token endpoint and allowed grant/scopes from that app's configuration. Client ID/secret presence alone does not prove Storage authorization. Never reuse a developer/admin CLI token as the deployed app credential.
4. Keep client secrets and Tachyon service tokens on the server. Authenticate the end user and authorize the attachment's owning record before issuing URLs, reading, or deleting. Derive the operator and allowed keys server-side rather than trusting arbitrary client-supplied values.

## Implement and Verify

- API upload: request `upload-url`, PUT the bytes to its signed URL, then require a successful `confirm` before saving the attachment reference. Persist `storage_key`, not the expiring signed URL.
- API read: issue a short-lived `get-url` after authorization, or use an authenticated server proxy. A URL returned by `confirm` is an API object URL, not evidence of public CDN access.
- Keep preview and production storage separate. Do not assume `app_id` is an authorization boundary or that every PR gets a distinct bucket. Verify actual bucket/key scope with the deployed identity.
- Move file seeding out of ad hoc `wrangler r2` build commands when adopting the API. Use an authorized import with stable source-to-key mapping and retry handling; do not import customer data merely to validate a skill.
- Verify with a small test file: upload, confirm, read back matching bytes, delete that test object, and verify it is absent. Check the authenticated UI for a user-facing change. Keep local tests, deployed API proof, and UI proof separate.

## Diagnose Failures

Locate the failing hop before proposing a change:

| Failing hop | Next check |
| --- | --- |
| Build calls Cloudflare `/accounts/.../r2/...`, error 10000/403 | Check whether the app is bypassing Tachyon Storage. Inspect the actual build credential source; do not default to expanding a shared Cloudflare token. |
| Tachyon API returns 401/403 | Check app identity, operator, resource policy, and bucket/key scope. |
| Tachyon API returns 500 with provider CreateBucket 403 | Escalate a platform provisioning credential problem with the request/build ID; app-side R2 credentials do not fix it. |
| Browser OPTIONS fails before signed PUT | Check the target bucket's CORS for the actual origin, method, and headers. |
| Signed PUT fails | Check expiry, exact URL, method, and matching Content-Type. Do not attach the Tachyon bearer token to R2. |
| Build succeeds but attachments fail | Inspect deployed storage configuration and exercise upload/read; removed bindings or skipped seeds can hide the failure. |

Report the selected path, evidence, required app changes, and any platform blocker. A request for guidance does not authorize a Slack reply, permission expansion, deployment, or data migration.
