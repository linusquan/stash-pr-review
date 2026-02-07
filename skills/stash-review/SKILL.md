---
name: stash-review
description: >
  Provides Bitbucket Stash (Bitbucket Server) integration knowledge for PR reviews.
  Use when reviewing PRs from Stash, fetching PR metadata via REST API,
  handling already-merged PRs, or resolving deleted branch refs.
  Automatically loaded when the review-pr command runs.
---

# Bitbucket Stash PR Review Integration

## When to Use This Skill

This skill is relevant when:
- Reviewing a PR that originated from Bitbucket Stash / Bitbucket Server
- A branch has been deleted after merge and you need to recover the diff
- You need PR metadata (title, description, reviewers, comments) from Stash
- You need to fetch the diff for an already-merged PR by PR number

## Environment Setup

The following environment variables must be set for Stash API access:

| Variable | Description | Example |
|----------|-------------|---------|
| `STASH_URL` | Base URL of your Bitbucket Server instance | `https://stash.yourcompany.com` |
| `STASH_USER` | Username for API authentication | `john.doe` |
| `STASH_TOKEN` | HTTP access token (generate in Stash: Profile → HTTP access tokens) | `MDk4...` |
| `STASH_DEFAULT_PROJECT` | Default project key when not specified | `PROJ` |

If any variable is missing, inform the user which ones are needed and how to set them:
```bash
export STASH_URL="https://stash.yourcompany.com"
export STASH_USER="your-username"
export STASH_TOKEN="your-http-access-token"
export STASH_DEFAULT_PROJECT="PROJ"
```

## Fetching PR Information

Use the helper script at `${CLAUDE_PLUGIN_ROOT}/skills/stash-review/scripts/fetch-pr-info.sh`:

```bash
# Fetch PR details
bash ${CLAUDE_PLUGIN_ROOT}/skills/stash-review/scripts/fetch-pr-info.sh details <PROJECT> <REPO> <PR_ID>

# Fetch PR commits
bash ${CLAUDE_PLUGIN_ROOT}/skills/stash-review/scripts/fetch-pr-info.sh commits <PROJECT> <REPO> <PR_ID>

# Fetch PR diff (from Stash API, not git)
bash ${CLAUDE_PLUGIN_ROOT}/skills/stash-review/scripts/fetch-pr-info.sh diff <PROJECT> <REPO> <PR_ID>
```

## Handling Already-Merged PRs

When a PR is already merged, there are three scenarios:

### Scenario 1: Branch still exists on remote

The merge-base approach works exactly the same:
```bash
MERGE_BASE=$(git merge-base origin/main origin/feature/xyz)
git diff $MERGE_BASE..origin/feature/xyz
```

### Scenario 2: Branch deleted, but you have the PR number

Use the Stash API to get the merge commit, then diff against its first parent:
```bash
# Get merge commit from PR metadata
MERGE_COMMIT=$(bash ${CLAUDE_PLUGIN_ROOT}/skills/stash-review/scripts/fetch-pr-info.sh details <PROJECT> <REPO> <PR_ID> | jq -r '.mergeCommit')

# Diff the merge commit against its first parent = the PR's changes
git diff ${MERGE_COMMIT}^..${MERGE_COMMIT}
```

### Scenario 3: Squash-merged, branch deleted

For squash merges, the merge commit IS the single squashed commit:
```bash
# Get the squash commit
MERGE_COMMIT=$(bash ${CLAUDE_PLUGIN_ROOT}/skills/stash-review/scripts/fetch-pr-info.sh details <PROJECT> <REPO> <PR_ID> | jq -r '.mergeCommit')

# For squash merge, diff against first parent
git diff ${MERGE_COMMIT}^..${MERGE_COMMIT}

# Or get all original commits from the Stash API (preserves individual commit history)
bash ${CLAUDE_PLUGIN_ROOT}/skills/stash-review/scripts/fetch-pr-info.sh commits <PROJECT> <REPO> <PR_ID>
```

## Stash REST API Quick Reference

Base: `${STASH_URL}/rest/api/1.0`

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/projects/{proj}/repos/{repo}/pull-requests/{id}` | GET | PR details |
| `/projects/{proj}/repos/{repo}/pull-requests/{id}/commits` | GET | PR commits |
| `/projects/{proj}/repos/{repo}/pull-requests/{id}/diff` | GET | PR diff |
| `/projects/{proj}/repos/{repo}/pull-requests/{id}/activities` | GET | PR activity (comments, approvals) |
| `/projects/{proj}/repos/{repo}/pull-requests/{id}/changes` | GET | Changed files list |
| `/projects/{proj}/repos/{repo}/pull-requests?state=OPEN` | GET | List open PRs |
| `/projects/{proj}/repos/{repo}/pull-requests?state=MERGED` | GET | List merged PRs |

All endpoints support pagination with `?start=0&limit=25`.

## Common Issues

**401 Unauthorized**: HTTP access token expired or invalid. Regenerate in Stash under Profile → HTTP access tokens.

**404 Not Found**: Check project key and repo slug are correct. Project keys are uppercase (e.g., `PROJ`, not `proj`). Repo slugs are lowercase with hyphens.

**Branch not found after merge**: Normal — many teams configure Stash to auto-delete branches on merge. Use the PR number approach (Scenario 2/3 above).

**Diff too large**: Stash API limits diff responses. For very large PRs, prefer the git merge-base approach over the API diff endpoint.
