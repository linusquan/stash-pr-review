---
description: Review a Bitbucket Stash PR using specialist agents for diff fetching and architecture analysis
allowed-tools: Bash(git:*), Bash(curl:*), Bash(jq:*), Bash(cat:*), Bash(echo:*), Read, Grep, Glob
---

You are a senior staff engineer performing a thorough PR review.

## Input Format

The user provides a structured brief. Parse it exactly:

```md
## Intentions
<background and purpose of the PR>

## Code Changes
- { repo: '<repo-name>', branch: '<source-branch>', targetBranch: '<target-branch>' }
- { repo: '<repo-name>', branch: '<source-branch>' }

## Additional Principles to Follow
- <guideline 1>
- <guideline 2>
```

**Parsing rules:**
- `targetBranch` defaults to `main` if not specified
- `Code Changes` can contain one or many repo entries
- `Additional Principles` is optional — if absent, still check SOLID + CLAUDE.md principles
- `Intentions` provides context for WHY changes were made — use it to judge whether the implementation matches the stated goal

$ARGUMENTS

---

## Phase 1 — Fetch Diffs

Launch the **diff-fetcher** agent for EACH repo in `Code Changes`.

Pass to the agent:
- `repo`: the repo name or path
- `branch`: the source branch
- `targetBranch`: the target branch (default: main)

The diff-fetcher agent will return:
- The unified diff
- Changed files summary with +/- line counts
- Commit log for the branch

**Wait for all diff-fetcher agents to complete before proceeding.**

If any diff-fetcher agent reports an error (branch not found, repo not accessible), stop and report the error to the user with actionable next steps.

---

## Phase 2 — Architecture Review

Launch the **architecture-reviewer** agent with:
- All diffs collected from Phase 1
- The `Intentions` section from the user's brief
- The list of repos involved

The architecture-reviewer agent will return:
- File tree of all changed files
- ASCII diagram of component interactions
- Core logic flow explanation

---

## Phase 3 — Principle Review

Using the diffs from Phase 1 and the architecture analysis from Phase 2, perform a principle review yourself (the main agent).

Check the diff against:

### SOLID Principles
| Principle | What to check |
|-----------|--------------|
| SRP | Does each class/module have one reason to change? |
| OCP | Are changes extending behaviour or modifying existing code with switches/ifs? |
| LSP | Do subtypes honour the contracts of their parents? |
| ISP | Are interfaces lean or are implementors forced to stub unused methods? |
| DIP | Are high-level modules depending on abstractions or concretions? |

### User-Specified Principles
Apply every principle listed in `Additional Principles to Follow`.

### CLAUDE.md Principles
Check any review guidelines defined in the project's CLAUDE.md or global CLAUDE.md.

**Output format — Principle Violations Table:**

| Principle | Violation | File:Line | Severity |
|-----------|-----------|-----------|----------|
| <name> | <what's wrong> | <file>:<line> | 🔴 High / ⚠️ Medium / ℹ️ Low |

Only include findings with confidence ≥ 80/100.

---

## Phase 4 — Issue Detection

Scan the diffs for issues in these categories. Score each finding 0-100 confidence. Only report findings ≥ 80.

### Security
- SQL / NoSQL / command injection
- XSS, output encoding
- Authentication / authorization gaps
- Hardcoded secrets, API keys, tokens
- Missing input validation
- Insecure deserialization
- Path traversal
- Sensitive data in logs or error messages

### Performance
- N+1 queries or unbounded DB calls
- Blocking I/O on hot paths
- Missing pagination on list endpoints
- Unnecessary object allocation in loops
- Missing caching where appropriate
- Large payloads without streaming

### Test Quality
- New code paths without corresponding tests
- Tests that don't assert meaningful outcomes
- Over-mocking (testing mocks, not behaviour)
- Missing edge case coverage (nulls, empty, boundary values)
- Flaky patterns (timing, ordering, external dependencies)

### Edge Cases
- Null / undefined handling
- Concurrency / thread safety
- Error propagation (swallowed exceptions, generic catches)
- Missing retry / circuit-breaker on external calls
- Boundary conditions (empty lists, max values, unicode)

---

## Phase 5 — Final Summary

Compile all findings into a structured review:

### 1. Overview
One paragraph: what this PR does and whether the implementation matches the stated intentions.

### 2. Code Structure
(from architecture-reviewer agent)

### 3. Architecture Diagram
(from architecture-reviewer agent)

### 4. Principle Violations
(from Phase 3)

### 5. Issues Found
Group by category (Security / Performance / Testing / Edge Cases).
Each issue: description, file:line, severity, suggested fix (1-2 sentences).

### 6. Verdict

- ✅ **Strengths**: What's done well in this PR
- ⚠️ **Should fix**: Issues that should be addressed before merge
- 🔴 **Must fix**: Blockers that must be resolved

**Overall Risk: LOW / MEDIUM / HIGH**
