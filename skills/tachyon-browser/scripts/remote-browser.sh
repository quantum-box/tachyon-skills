#!/usr/bin/env bash
set -euo pipefail

gateway="${TACHYON_BROWSER_GATEWAY:-http://browser-cdp.intra.quantum-box.com:9222}"
session_id=""
temporary=0
cleanup=0
agent_session=""

usage() {
  cat <<'USAGE'
Usage:
  remote-browser.sh [--session-id ID | --temporary] [--cleanup | --keep] [--gateway URL] [--agent-session NAME] -- <agent-browser args...>
  remote-browser.sh --delete SESSION_ID
  remote-browser.sh --list

Environment:
  TACHYON_BROWSER_API_TOKEN  Gateway API token (required). Never printed.
  TACHYON_BROWSER_GATEWAY    Gateway base URL (default: http://browser-cdp.intra.quantum-box.com:9222)

Without agent-browser args, prints the session's cdp_ws_url to stdout.
The URL contains the session token; treat it as a secret.

Examples:
  remote-browser.sh --session-id sakura-job-001 -- open https://example.com
  remote-browser.sh --temporary --cleanup -- open https://example.com
  remote-browser.sh --temporary --keep -- open https://example.com
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "remote-browser.sh: missing required command: $1" >&2
    exit 127
  fi
}

require_token() {
  if [[ -z "${TACHYON_BROWSER_API_TOKEN:-}" ]]; then
    echo "remote-browser.sh: TACHYON_BROWSER_API_TOKEN is not set (gateway API token)" >&2
    exit 2
  fi
}

urlencode() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import quote
print(quote(sys.argv[1], safe=""))
PY
}

# Calls the gateway with the API token. The Authorization header is read from
# a process substitution so the token never appears in curl's arguments.
gateway_request() {
  local method="$1" path="$2" body="${3:-}"
  require_cmd curl
  require_token
  local args=(-sS --fail-with-body -X "$method")
  if [[ -n "$body" ]]; then
    args+=(-H 'content-type: application/json' --data "$body")
  fi
  curl "${args[@]}" \
    -H @<(printf 'Authorization: Bearer %s\n' "$TACHYON_BROWSER_API_TOKEN") \
    "${gateway}${path}"
}

# Replaces the session token segment of a session URL for logging.
mask_session_url() {
  sed -E 's#(/sessions/[^/]+/)[A-Za-z0-9_-]{43}#\1<session_token>#' <<<"$1"
}

delete_session() {
  local id="$1"
  require_cmd jq
  local encoded
  encoded="$(urlencode "$id")"
  gateway_request DELETE "/sessions/${encoded}" | jq .
}

list_sessions() {
  require_cmd jq
  gateway_request GET /sessions | jq .
}

while (($# > 0)); do
  case "$1" in
    --gateway)
      gateway="${2:?missing value for --gateway}"
      shift 2
      ;;
    --session-id)
      session_id="${2:?missing value for --session-id}"
      shift 2
      ;;
    --temporary)
      temporary=1
      shift
      ;;
    --cleanup)
      cleanup=1
      shift
      ;;
    --keep)
      cleanup=0
      shift
      ;;
    --agent-session)
      agent_session="${2:?missing value for --agent-session}"
      shift 2
      ;;
    --delete)
      delete_session "${2:?missing session id for --delete}"
      exit 0
      ;;
    --list)
      list_sessions
      exit 0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

require_cmd curl
require_cmd jq
require_token
if (($# > 0)); then
  require_cmd agent-browser
fi

if [[ -n "$session_id" && "$temporary" == "1" ]]; then
  echo "remote-browser.sh: choose either --session-id or --temporary, not both" >&2
  exit 2
fi

request_body=""
if [[ -n "$session_id" ]]; then
  request_body="$(jq -cn --arg id "$session_id" '{session_id: $id}')"
fi

# POST /sessions creates the session Pod (or reuses a named one) and returns
# cdp_ws_url, which carries the session token in its path.
if ! session_json="$(gateway_request POST /sessions "$request_body")"; then
  echo "remote-browser.sh: failed to create session" >&2
  printf '%s\n' "$session_json" | jq -c 'del(.session_token?)' >&2 2>/dev/null || true
  exit 1
fi
session_id="$(jq -r .session_id <<<"$session_json")"
cdp_ws="$(jq -r .cdp_ws_url <<<"$session_json")"
if [[ -z "$session_id" || "$session_id" == "null" || -z "$cdp_ws" || "$cdp_ws" == "null" ]]; then
  echo "remote-browser.sh: gateway response did not include session_id and cdp_ws_url" >&2
  exit 1
fi

if [[ -z "$agent_session" ]]; then
  agent_session="$session_id"
fi

echo "remote-browser.sh: session_id=${session_id}" >&2
echo "remote-browser.sh: cdp_ws=$(mask_session_url "$cdp_ws")" >&2

if (($# == 0)); then
  printf '%s\n' "$cdp_ws"
  exit 0
fi

if [[ "$cleanup" == "1" ]]; then
  trap 'delete_session "$session_id" >/dev/null 2>&1 || true' EXIT
fi

agent-browser --cdp "$cdp_ws" --session "$agent_session" "$@"
