# Status

Show current project state. Used by both user (visibility) and orchestrator (routing).

## What to Report

1. **Worktree** - Are we in main repo or a worktree?
2. **Branch** - Current git branch
3. **Issue** - Extracted from branch (e.g., `feature/123_inbox-filters` → #123)
4. **GitHub Issue** - Fetch issue title/status via `gh issue view {ISSUE_NUMBER}` or GitHub MCP (if unavailable, note "GitHub CLI unavailable")
5. **Plan** - From `.claude/issues/{ISSUE_NUMBER}.plan.md`:
   - Exists?
   - Status checkboxes
   - Tasks completed vs total
6. **Review** - From `.claude/issues/{ISSUE_NUMBER}.review.md`:
   - Exists?
   - Verdict if exists
7. **Git** - Uncommitted changes, ahead/behind remote
8. **Active Worktrees** - If in main repo, list all worktrees
9. **State** - One of: `no-issue`, `needs-plan`, `needs-approval`, `implementing`, `reviewing`, `iterating`, `needs-revision`, `approved`, `finalized`

## Branch Parsing

Extract issue number from branch name using pattern:
- `feature/{ISSUE_NUMBER}_description` → {ISSUE_NUMBER}
- `bugfix/{ISSUE_NUMBER}_description` → {ISSUE_NUMBER}
- Legacy: `{ISSUE_NUMBER}-description` → {ISSUE_NUMBER}

## State Detection

| Condition | State |
|-----------|-------|
| No issue detected | `no-issue` |
| No plan file | `needs-plan` |
| Plan drafted, not approved | `needs-approval` |
| Plan approved, implementation incomplete | `implementing` |
| Implementation complete, no review yet | `reviewing` |
| Review: 🔄 Iterate | `iterating` |
| Review: 🛑 Revise Plan | `needs-revision` |
| Review: ✅ Approved | `approved` |
| Already committed/pushed | `finalized` |

## Output Format

### When in a worktree:
```
Worktree: /path/to/repo-123 (main repo: /path/to/repo)
Branch:   feature/123_inbox-filters
Issue:    #123 - Add filtering to inbox
Status:   Open

Plan:     .claude/issues/123.plan.md
          [x] Plan drafted
          [x] Plan approved by user
          [ ] Implementation complete
          [ ] Code review approved
          Tasks: 5/8 complete

Review:   Not yet created

Git:      3 files modified, not committed
          Branch is up to date with origin

State:    implementing
Next:     Continue implementation (run /go:eng)
```

### When in main repo:
```
Repo:     /path/to/repo (main)
Branch:   main

Active Worktrees:
  - /path/to/repo-123 → feature/123_add-feature (2 files modified)
  - /path/to/repo-456 → feature/456_fix-bug (clean)

State:    no-issue
Next:     Run /go:go {ISSUE_NUMBER} to start a new issue (creates worktree)
```

## Commands

```bash
git branch --show-current
git status --short
git log origin/main..HEAD --oneline

# Check if in worktree
IS_WORKTREE=$([ "$(git rev-parse --git-common-dir)" != "$(git rev-parse --git-dir)" ] && echo "true" || echo "false")

# List all worktrees (from main repo)
git worktree list

# Get GitHub issue details
gh issue view {ISSUE_NUMBER}
```
