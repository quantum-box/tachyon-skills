---
name: agent-api-langfuse-smoke
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Use when the Tachyon Agent API may be broken, when the user asks to verify Agent API behavior
  end-to-end, or when the user wants to inspect the real provider request body through Langfuse
  sessions/traces.
---

# Agent API Langfuse Smoke

## Purpose

Verify that the Agent API actually ran and that the recursive LLM/tool loop can
be inspected through local Langfuse. Prefer concrete runtime evidence over
code-only conclusions.

This skill is for local Tachyon development with:

- Tachyon API: `http://localhost:50054`
- Langfuse UI: `http://localhost:3000`
- Langfuse project: use the project configured for the local environment.
- Dev operator and user: resolve locally from the seed files; do not copy their IDs into plugin docs.

Langfuse local sign-in, when needed:

```text
email: admin@example.com
password: "${LANGFUSE_LOCAL_PASSWORD}"
```

Load the password from ignored local configuration; never store the value in a
skill or taskdoc.

## What This Confirms

- Agent API endpoint accepts the request.
- A Langfuse session is created or reused.
- `agent.llm_generation` traces are grouped by `sessionId`.
- The child `llm.generation` observation contains the real provider request at
  `input.provider_api_request`.
- Recursive/tool runs create an `agent.execute_tool` trace in the same session.
- Provider, model, usage, tenant, user, and output are visible for debugging.

Langfuse is observability, not a full test runner. Use scenario tests or API
assertions for DB state and business invariants.

## Preconditions

Preferred automated smoke command:

```bash
scripts/test/agent-api-langfuse-smoke.sh
```

Use this script first when it exists. It creates an Agent Session, runs a
minimal Agent API request, waits for Langfuse traces, verifies
`input.provider_api_request`, optionally exercises the tool loop, and prints the
Langfuse session/trace URLs plus saved artifacts. Override local settings with
`TACHYON_API_BASE_URL`, `LANGFUSE_BASE_URL`, `AGENT_MODEL`,
`AGENT_LANGFUSE_TOOL_SMOKE`, `AGENT_LANGFUSE_BUILTIN_TOOLS`, and
`AGENT_LANGFUSE_OUTPUT_DIR` when needed.

Check the local services:

```bash
docker compose ps
curl -sf http://localhost:50054/health
curl -sf http://localhost:3000/api/public/health || true
```

If Langfuse traces are missing, verify the API was started with:

```bash
LANGFUSE_ENABLED=true
OTEL_ENABLED=true
LANGFUSE_ENVIRONMENT=local
TACHYON_AGENT_BILLING_ENABLED=false
```

`docker-compose.langfuse.yml` defaults Agent billing to disabled so local
observability/deep-research smoke tests are not interrupted by dev Stripe
configuration. Set `TACHYON_AGENT_BILLING_ENABLED=true` explicitly only when the
test is meant to verify billing.

For this workspace, a known working dev command is:

```bash
LANGFUSE_ENABLED=true OTEL_ENABLED=true LANGFUSE_ENVIRONMENT=local \
TACHYON_AGENT_BILLING_ENABLED=false \
  docker compose -f compose.yml -f docker-compose.langfuse.yml run -d \
  --service-ports --name tachyon-api-mold-run \
  tachyon-api mold -run cargo run --bin tachyon-api
```

Do not kill or replace an existing API container unless it is clearly stale or
the user asked for a restart.

## Smoke Test: Create Session

Create a fresh Agent Session and keep the session id:

```bash
: "${TACHYON_OPERATOR_ID:?Set this from the local dev seed}"
: "${TACHYON_USER_ID:?Set this from the local dev seed}"
MARKER="langfuse-agent-smoke-$(date +%s)"
SESSION_JSON=$(curl -sS -X POST 'http://localhost:50054/v1/llms/sessions' \
  -H 'Authorization: Bearer dummy-token' \
  -H "x-operator-id: ${TACHYON_OPERATOR_ID}" \
  -H "x-user-id: ${TACHYON_USER_ID}" \
  -H 'Content-Type: application/json' \
  --data-binary "{\"name\":\"${MARKER}\",\"metadata\":{\"marker\":\"${MARKER}\",\"purpose\":\"agent-api-langfuse-smoke\"}}")
SESSION_ID=$(printf '%s' "$SESSION_JSON" | jq -r '.session_id')
printf 'SESSION_ID=%s\nMARKER=%s\n' "$SESSION_ID" "$MARKER"
```

## Smoke Test: LLM Request

Run a minimal Agent API request. Omit `model` first so the tenant's default
agent model is used. If a specific model returns `Model ... is not available`,
fall back to the default model.

```bash
curl -sS -N -X POST "http://localhost:50054/v1/llms/sessions/${SESSION_ID}/agent/execute" \
  -H 'Authorization: Bearer dummy-token' \
  -H "x-operator-id: ${TACHYON_OPERATOR_ID}" \
  -H "x-user-id: ${TACHYON_USER_ID}" \
  -H 'Content-Type: application/json' \
  --data-binary "{\"task\":\"Return exactly this marker and nothing else: ${MARKER}\",\"auto_approve\":true,\"max_requests\":1,\"chatroom_name_generation\":\"never\"}"
```

It is acceptable for a later billing step to emit a dev configuration error such
as `Stripe secret_key has invalid format`, as long as the LLM generation trace
was emitted. Report that distinction clearly.

## Smoke Test: Tool Loop

Use this when the user asks whether the recursive/tool loop works:

```bash
TOOL_MARKER="langfuse-agent-tool-$(date +%s)"
curl -sS -N -X POST "http://localhost:50054/v1/llms/sessions/${SESSION_ID}/agent/execute" \
  -H 'Authorization: Bearer dummy-token' \
  -H "x-operator-id: ${TACHYON_OPERATOR_ID}" \
  -H "x-user-id: ${TACHYON_USER_ID}" \
  -H 'Content-Type: application/json' \
  --data-binary "{\"task\":\"Call the TodoWrite tool with one completed todo whose content is '${TOOL_MARKER}'. After the tool result, call attempt_completion with result '${TOOL_MARKER}'.\",\"auto_approve\":true,\"max_requests\":2,\"chatroom_name_generation\":\"never\"}"
```

Expected stream evidence:

- `event: tool_call`
- `event: tool_call_args`
- `event: tool_result`

## Query Langfuse From CLI

Use the local project public/secret key pair. Do not print external production
keys.

```bash
AUTH=$(printf 'pk-lf-local-tachyon:sk-lf-local-tachyon' | base64)
curl -sS 'http://localhost:3000/api/public/traces?limit=50' \
  -H "Authorization: Basic ${AUTH}" \
  | jq --arg session_id "$SESSION_ID" '
      [.data[]
       | select(.sessionId == $session_id)
       | {id, name, sessionId, userId, timestamp, metadata}]'
```

Expected trace names:

- `agent.llm_generation`
- `agent.execute_tool` when the tool smoke was run

Inspect the actual provider request:

```bash
TRACE_ID="<agent.llm_generation_trace_id>"
curl -sS "http://localhost:3000/api/public/traces/${TRACE_ID}" \
  -H "Authorization: Basic ${AUTH}" \
  | jq '
      .observations[]
      | select(.name == "llm.generation")
      | .input.provider_api_request'
```

Useful compact request summary:

```bash
curl -sS "http://localhost:3000/api/public/traces/${TRACE_ID}" \
  -H "Authorization: Basic ${AUTH}" \
  | jq '
      .observations[]
      | select(.name == "llm.generation")
      | .input.provider_api_request
      | {
          provider,
          method,
          path,
          body: {
            model: .body.model,
            stream: .body.stream,
            max_tokens: .body.max_tokens,
            messages_count: (.body.messages | length),
            tools: [.body.tools[]?.name],
            first_user_message: .body.messages[0].content
          }
        }'
```

## Inspect In Langfuse UI

Session URL:

```text
http://localhost:3000/project/proj-local-tachyon/sessions/<SESSION_ID>
```

Trace URL:

```text
http://localhost:3000/project/proj-local-tachyon/traces/<TRACE_ID>
```

To find the actual provider request in the UI:

1. Open the session.
2. Open an `agent.llm_generation` trace.
3. In the left navigation tree, select the child `llm.generation`
   observation, not the parent `handle` span.
4. In the details panel, select `Preview` then `JSON`.
5. Look under `Input`.
6. The actual provider HTTP request is:
   `provider_api_request.body`.

Do not confuse these:

- `input.messages` is Tachyon's normalized observability input.
- `input.provider_api_request.body` is the actual provider API request body.
- `metadata.request_body.provider_api_request` is a metadata copy useful for
  search/debugging.

If `search_with_llm` or `fetch_url` is missing from
`input.provider_api_request.body.tools`, the Agent API request did not enable
the corresponding built-in tools. Pass them explicitly, for example:

```bash
AGENT_LANGFUSE_BUILTIN_TOOLS=web_search,url_fetch \
  scripts/test/agent-api-langfuse-smoke.sh
```

## Troubleshooting

- No Langfuse traces: wait a few seconds, then check `LANGFUSE_ENABLED=true`,
  `OTEL_ENABLED=true`, `otel-collector`, and `langfuse-web`.
- Request body missing: select the child `llm.generation` observation and switch
  to `JSON`.
- Model unavailable: omit `model` and use the default agent model.
- Tool trace missing: make the task explicitly require `TodoWrite`, set
  `auto_approve=true`, and allow `max_requests=2`.
- API returns Stripe secret errors after output: report it as a dev billing
  configuration failure, not necessarily an LLM/provider failure.
- Sign-in required: use the local Langfuse credentials in this skill.

## Report Format

When reporting results to the user, include:

- Session URL.
- `agent.llm_generation` trace URL.
- `agent.execute_tool` trace URL when applicable.
- Provider request summary: provider, method, path, model, stream, tool names.
- Any error event and whether it happened before or after LLM/tool evidence.
