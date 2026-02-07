# stash-pr-review — Claude Code Plugin (v0.1)

Automated PR review for Bitbucket Stash with specialist subagents.

## Quick Start

### 1. Install the plugin

```bash
# Option A: Symlink (recommended for development)
ln -s /path/to/stash-pr-review ~/.claude/plugins/stash-pr-review

# Option B: Copy
cp -r /path/to/stash-pr-review ~/.claude/plugins/stash-pr-review
```

### 2. Set environment variables (for Stash API access)

```bash
export STASH_URL="https://stash.yourcompany.com"
export STASH_USER="your-username"
export STASH_TOKEN="your-http-access-token"
export STASH_DEFAULT_PROJECT="PROJ"
```

### 3. Make the helper script executable

```bash
chmod +x ~/.claude/plugins/stash-pr-review/skills/stash-review/scripts/fetch-pr-info.sh
```

## Usage

### Review an open PR

```
claude> /review-pr
## Intentions
Add async payment notification system after successful payment processing.

## Code Changes
- { repo: 'payment-service', branch: 'feature/async-notify', targetBranch: 'main' }

## Additional Principles to Follow
- All new services must use constructor injection
- Async operations must have retry + dead-letter handling
```

### Review across multiple repos

```
claude> /review-pr
## Intentions
Introduce shared event schema for cross-service communication.

## Code Changes
- { repo: 'common-lib', branch: 'feature/event-schema', targetBranch: 'main' }
- { repo: 'order-service', branch: 'feature/event-schema', targetBranch: 'main' }
- { repo: 'notification-service', branch: 'feature/event-schema', targetBranch: 'develop' }
```

### Review an already-merged PR

Use the same format — merge-base handles it if the branch ref still exists.
If the branch is deleted, provide the merge commit SHA as the branch value.

## What It Produces

1. **File Structure Map** — changed files grouped by concern with +/- counts
2. **ASCII Architecture Diagram** — component interaction flow
3. **Core Logic Flow** — narrative explanation of what the code does
4. **Principle Violations** — SOLID + custom principles, with file:line refs
5. **Issue Detection** — security, performance, test quality, edge cases
6. **Verdict** — strengths, should-fix, must-fix, overall risk level

## Plugin Structure

```
stash-pr-review/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   └── review-pr.md
├── agents/
│   ├── diff-fetcher.md
│   └── architecture-reviewer.md
├── skills/
│   └── stash-review/
│       ├── SKILL.md
│       └── scripts/
│           └── fetch-pr-info.sh
└── README.md
```
