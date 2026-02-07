#!/bin/bash
# fetch-pr-info.sh — Fetch PR metadata from Bitbucket Stash REST API
#
# Usage:
#   fetch-pr-info.sh details <PROJECT> <REPO> <PR_ID>
#   fetch-pr-info.sh commits <PROJECT> <REPO> <PR_ID>
#   fetch-pr-info.sh diff    <PROJECT> <REPO> <PR_ID>
#
# Environment:
#   STASH_URL    — Base URL (e.g. https://stash.yourcompany.com)
#   STASH_USER   — Username
#   STASH_TOKEN  — HTTP access token

set -euo pipefail

# ── Validate environment ──────────────────────────────────────────

if [[ -z "${STASH_URL:-}" ]]; then
  echo "ERROR: STASH_URL not set. Export it: export STASH_URL='https://stash.yourcompany.com'" >&2
  exit 1
fi

if [[ -z "${STASH_USER:-}" || -z "${STASH_TOKEN:-}" ]]; then
  echo "ERROR: STASH_USER and STASH_TOKEN must be set for API authentication." >&2
  echo "Generate a token: Stash → Profile → HTTP access tokens" >&2
  exit 1
fi

# ── Parse arguments ───────────────────────────────────────────────

ACTION="${1:-}"
PROJECT="${2:-}"
REPO="${3:-}"
PR_ID="${4:-}"

if [[ -z "$ACTION" || -z "$PROJECT" || -z "$REPO" || -z "$PR_ID" ]]; then
  echo "Usage: $(basename "$0") <details|commits|diff> <PROJECT> <REPO> <PR_ID>" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $(basename "$0") details PROJ my-repo 42" >&2
  echo "  $(basename "$0") commits PROJ my-repo 42" >&2
  echo "  $(basename "$0") diff    PROJ my-repo 42" >&2
  exit 1
fi

BASE="${STASH_URL}/rest/api/1.0/projects/${PROJECT}/repos/${REPO}/pull-requests/${PR_ID}"
AUTH="-u ${STASH_USER}:${STASH_TOKEN}"

# ── Helper: curl with error handling ──────────────────────────────

fetch() {
  local url="$1"
  local response
  local http_code

  response=$(curl -s -w "\n%{http_code}" ${AUTH} "${url}")
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" -ge 400 ]]; then
    echo "ERROR: HTTP ${http_code} from ${url}" >&2
    echo "$body" | jq -r '.errors[]?.message // "Unknown error"' 2>/dev/null >&2 || echo "$body" >&2
    exit 1
  fi

  echo "$body"
}

# ── Actions ───────────────────────────────────────────────────────

case "$ACTION" in

  details)
    fetch "${BASE}" | jq '{
      id: .id,
      title: .title,
      description: .description,
      state: .state,
      author: .author.user.displayName,
      fromBranch: .fromRef.displayId,
      toBranch: .toRef.displayId,
      fromCommit: .fromRef.latestCommit,
      toCommit: .toRef.latestCommit,
      mergeCommit: (.properties.mergeCommit.id // null),
      reviewers: [.reviewers[] | {
        name: .user.displayName,
        status: .status
      }],
      createdDate: (.createdDate / 1000 | strftime("%Y-%m-%d %H:%M:%S")),
      updatedDate: (.updatedDate / 1000 | strftime("%Y-%m-%d %H:%M:%S"))
    }'
    ;;

  commits)
    START=0
    LIMIT=25
    ALL_COMMITS="[]"

    while true; do
      RESPONSE=$(fetch "${BASE}/commits?start=${START}&limit=${LIMIT}")
      COMMITS=$(echo "$RESPONSE" | jq '.values')
      COUNT=$(echo "$COMMITS" | jq 'length')
      ALL_COMMITS=$(echo "$ALL_COMMITS $COMMITS" | jq -s 'add')

      IS_LAST=$(echo "$RESPONSE" | jq '.isLastPage')
      if [[ "$IS_LAST" == "true" || "$COUNT" -eq 0 ]]; then
        break
      fi
      START=$(echo "$RESPONSE" | jq '.nextPageStart')
    done

    echo "$ALL_COMMITS" | jq '[.[] | {
      id: .id,
      displayId: .displayId,
      message: .message,
      author: .author.name,
      date: (.authorTimestamp / 1000 | strftime("%Y-%m-%d %H:%M:%S"))
    }]'
    ;;

  diff)
    fetch "${BASE}/diff?contextLines=5" | jq '{
      diffs: [.diffs[] | {
        source: (.source.toString // null),
        destination: (.destination.toString // null),
        hunks: (.hunks | length),
        truncated: .truncated
      }]
    }'
    ;;

  *)
    echo "ERROR: Unknown action '${ACTION}'. Use: details, commits, or diff" >&2
    exit 1
    ;;

esac
