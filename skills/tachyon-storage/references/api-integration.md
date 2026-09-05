# Storage API Integration

Use this contract as a starting point and check it against the target deployment's OpenAPI/SDK. The API base URL is deployment-specific. Examples are server-side unless explicitly marked as a browser PUT.

## Authentication and Ownership

Tachyon requests require `Authorization: Bearer <app access token>` and `x-operator-id: <acting tenant>`. Obtain the token through the app's supported authentication flow; resolve the OAuth endpoint, grant and scopes from deployment configuration rather than guessing them. Never put a client secret or app bearer token in browser code, `NEXT_PUBLIC_*`, or a build log.

The app server must authorize the user's access to the owning record. For confirm/read/delete, load the storage key from that record or from a server-maintained pending upload. Do not let a browser submit arbitrary tenant IDs, bucket names, or keys and act on them with the app's credentials.

## Default Upload Flow

1. Server: `POST /v1/storage/upload-url`:

   ```json
   { "content_type": "image/png", "extension": "png", "app_id": "attachments" }
   ```

   Returns `{url, storage_key, expires_in_secs}`. Optional request fields include `folder` and `tenant_id`; omit `tenant_id` for the acting tenant. Selecting a descendant tenant still requires authorization. `app_id` is a key namespace, not proof of isolation. There is no `bucket` request field here.

2. Browser or server: PUT bytes to the returned URL, using the same Content-Type. Send no Tachyon Authorization header. Browser use also requires bucket CORS to allow the app origin and PUT headers.

3. Server: `POST /v1/storage/confirm` with `{ "storage_key": "<returned key>" }`. Require success and validate returned `content_type` and `content_length` against the app's attachment rules. Save the storage key and metadata only after this succeeds. A failed PUT/confirm must not create a completed attachment row.

A minimal server-side sequence, with authentication supplied by the app:

```ts
async function storeAttachment(
  apiBase: string,
  accessToken: string,
  operatorId: string,
  bytes: Uint8Array,
  contentType: string,
  extension: string,
) {
  async function post(path: string, body: unknown) {
    const response = await fetch(`${apiBase}${path}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'x-operator-id': operatorId,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    })
    if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`)
    return response.json()
  }

  // Validate size/type and authorize the owning record before calling this.
  const pending = await post('/v1/storage/upload-url', {
    content_type: contentType, extension, app_id: 'attachments',
  })
  const put = await fetch(pending.url, {
    method: 'PUT',
    headers: { 'Content-Type': contentType },
    body: new Uint8Array(bytes).buffer,
  })
  if (!put.ok) throw new Error(`Storage PUT: HTTP ${put.status}`)
  const confirmed = await post('/v1/storage/confirm', {
    storage_key: pending.storage_key,
  })
  if (confirmed.content_length !== bytes.byteLength ||
      confirmed.content_type !== contentType) {
    throw new Error('Storage confirmation metadata mismatch')
  }
  return confirmed // Persist storage_key, not pending.url.
}
```

Do not log signed URLs or response bodies containing credentials. This helper does not replace the app's user authorization, size limits, pending-upload tracking, or orphan cleanup strategy.

## Read, Delete, and Explicit Buckets

| Endpoint | JSON body | Result/use |
| --- | --- | --- |
| `POST /v1/storage/get-url` | `storage_key`, optional `expires_in_secs`, `bucket`, `tenant_id` | Signed GET URL and expiry; request after app authorization. |
| `POST /v1/storage/delete` | `storage_key`, optional `bucket`, `tenant_id` | Delete only the authorized object's data; coordinate attachment row removal and retries. |
| `GET /v1/storage/objects/<encoded key>` | No JSON body | Authenticated object proxy. Preserve path separators when encoding key segments. |
| `POST /v1/storage/presigned-url` | `key`, `method` (`GET` or `PUT`), optional `content_type`, `expires_in_secs`, `bucket`, `tenant_id` | Sign an explicitly chosen key/bucket after checking ownership. |

For a Cloud App managed bucket, use the resolved physical bucket name and confirm that the app identity is authorized for it. Explicit-bucket PUT uses `presigned-url`, followed by PUT and `confirm` with the same `bucket` and `storage_key`. Use the same bucket for subsequent reads/deletes. Do not silently fall back to the default bucket on an authorization error. Bucket omission on the object proxy must not be assumed equivalent to explicit-bucket requests.

## Migrating an Existing Attachment Adapter

- Inventory the current put/get/delete adapter, key format, DB references, and seed/import scripts. Confirm whether old files actually exist; an empty or disabled binding is not a completed migration.
- Keep the app's storage interface where practical. If Tachyon generates new keys, persist a source-key → storage-key mapping instead of treating old local paths as new keys.
- For a restartable import, retain a stable source identifier, content hash, destination key/bucket, and completion status. Reuse pending keys for retries where the API permits it; skip only confirmed matching objects. Never rerun a key-generating upload blindly after a timeout.
- Keep the existing read path available until migrated objects are verified. Remove old data only within explicitly authorized migration scope.
- Distinguish default tenant storage from per-app/per-binding managed buckets. Managed preview buckets may be shared across PRs; verify actual behavior and use PR-specific namespaces when needed. A prefix convention alone does not enforce authorization.

## Source Checks

If the Tachyon platform checkout is available, the authoritative request/response definitions are in `packages/storage/src/adapter/axum/mod.rs`. Managed bucket semantics are documented in `docs/src/for-developers/cloudapp-manifest-environments.md`. These are maintainer references, not prerequisites for public plugin users: use the target deployment's API contract or installed SDK when the private repository is unavailable.
