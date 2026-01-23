# Status

Show current project state. Used by both user (visibility) and orchestrator (routing).

## What to Report

1. **Branch** - Current git branch
2. **Issue** - Extracted from branch (e.g., `feature/123_inbox-filters` → #123)
3. **GitHub Issue** - Fetch issue title/status via `gh issue view {ISSUE_NUMBER}` or GitHub MCP (if unavailable, note "GitHub CLI unavailable")
4. **Plan** - From `.claude/issues/{ISSUE_NUMBER}.plan.md`:
   - Exists?
   - Status checkboxes
   - Tasks completed vs total
5. **Review** - From `.claude/issues/{ISSUE_NUMBER}.review.md`:
   - Exists?
   - Verdict if exists
6. **Git** - Uncommitted changes, ahead/behind remote
7. **State** - One of: `no-issue`, `needs-plan`, `needs-approval`, `implementing`, `reviewing`, `iterating`, `needs-revision`, `approved`, `finalized`

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

```
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

## Commands

```bash
git branch --show-current
git status --short
git log origin/main..HEAD --oneline

# Get GitHub issue details
gh issue view {ISSUE_NUMBER}
```
