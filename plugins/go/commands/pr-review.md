# PR Reviewer Agent (External)

Review another developer's PR. Provide feedback for user to share in code review.

## Purpose

When user asks to review a PR or another dev's branch:
1. Pull/checkout the branch
2. Check for existing plan/review files (other users use Claude too)
3. Review against same standards as internal review
4. Output structured feedback for PR comments

**This is NOT part of the iteration loop** - just feedback generation.

## Process

1. **Get branch info**
   ```bash
   git fetch origin
   git checkout origin/feature-branch
   ```

2. **Understand context (fresh eyes)**
   - Extract issue number from branch name (e.g., `feature/123_feature` → #123)
   - Fetch issue via `gh issue view {ISSUE_NUMBER}` - this is the source of truth
   - **Do NOT read the plan file** - review with fresh perspective, not the implementer's thinking

3. **Review changes**
   - `git diff main...HEAD`
   - Read each changed file
   - Verify code meets issue requirements (not the implementer's interpretation)

4. **Handle tests and migrations**

   Check `.claude/issues/{ISSUE_NUMBER}.review.md` **only for test status**:

   **If review file exists with ✅ and no new commits since:**
   - Trust existing test results
   - Note: "Tests verified per existing review file"
   - Skip re-running tests

   **If no review file or new commits:**
   - Check if PR includes migrations (`git diff main...HEAD -- */migrations/`)
   - **Never run unmerged migrations locally**
   - Run tests that don't require new migrations
   - For migration-dependent tests: note in output

5. **Check standards**
   - Security
   - Bugs/logic errors
   - Code standards
   - Test coverage
   - E2E coverage for UI changes

6. **Generate feedback**

## Output Format

```markdown
# PR Review: #{ISSUE_NUMBER}

**Branch:** feature-branch
**Recommendation:** ✅ Approve | 🔄 Request Changes | ❌ Needs Discussion

---

## Summary

Brief overall assessment (2-3 sentences).

## File Comments

### `path/to/file.py`

**Line 42:** [Comment]
```python
# Suggested change if applicable
```

**Line 78-82:** [Comment]

### `path/to/other.vue`

**Line 15:** [Comment]

## General Feedback

- [Overall observation 1]
- [Overall observation 2]

## Tests

- Backend: [pass/fail/trusted from review file]
- Frontend: [pass/fail/trusted from review file]
- E2E: [pass/fail/trusted from review file/not applicable]
- ⚠️ Has migrations - verify tests pass in CI/after merge (if applicable)

---

*Copy relevant sections to PR comments*
```

## Comment Guidelines

Be constructive:
- **Good:** "Consider extracting this to a helper for reuse"
- **Bad:** "This is messy"

Distinguish severity:
- 🔴 **Blocker:** Must fix before merge
- 🟡 **Suggestion:** Would improve but not blocking
- 💭 **Question:** Seeking clarification

## After Review

Return to user's original branch:
```bash
git checkout -
```

Tell user: "Review complete. Copy feedback above to PR comments."
