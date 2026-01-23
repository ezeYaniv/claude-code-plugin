# Retro

Review the current issue's journey and extract learnings. Called by finalize before commit.

## Process

1. **Gather context:**
   - Read `.claude/issues/{ISSUE_NUMBER}.plan.md`
   - Read `.claude/issues/{ISSUE_NUMBER}.review.md`
   - Note iterations (Fixed This Cycle section)

2. **Identify patterns:**
   - What was corrected during review?
   - What did engineer miss?
   - Any "Plan Revision Required" moments?
   - User corrections or feedback?

3. **Categorize each learning:**

   **Universal (→ plugin):**
   - Workflow improvements
   - TDD patterns and anti-patterns
   - Review process improvements
   - Planning structure changes

   **Project-Specific (→ project's .claude/):**
   - Directory layout conventions
   - Project-specific test patterns
   - Tech stack specifics
   - Naming conventions

4. **Apply learnings by category:**
   - Project-specific → update `.claude/` files (will be in commit)
   - Universal → queue for after project push

5. **Report what was updated**

## Output Format

```markdown
## Retro: #{ISSUE_NUMBER}

### What Happened
- Brief summary of issue and implementation

### Iterations
- Review cycle 1: Fixed X, Y
- Review cycle 2: Fixed Z

### Learnings Identified

#### Project-Specific (included in commit)

**1. [Learning title]**
- Pattern: What went wrong
- Target: .claude/standards.md
- Added: "[exact text]"

#### Universal (will push to plugin after finalize)

**2. [Learning title]**
- Pattern: What went wrong
- Target: commands/rev.md
- Proposed: "[exact text]"

### Summary
- Project-specific updates: X files modified
- Universal updates: X pending for plugin
```

## When No Learnings

```markdown
## Retro: #{ISSUE_NUMBER}

Clean implementation - no new learnings identified.
Approved on first review with no iterations.
```

## Integration with Finalize

Retro is called early in finalize, before the commit:

1. Finalize calls retro
2. Retro applies project-specific learnings to `.claude/` files
3. Retro queues universal learnings
4. Finalize commits everything (code + project learnings)
5. Finalize pushes project branch
6. Finalize applies universal learnings to plugin

This ensures:
- Project learnings ship with the code that triggered them
- Universal learnings update the shared plugin
- One PR, cohesive changes

## Standalone Usage

```
/go:retro
```
Reviews current issue (from branch). If called outside finalize, will prompt about committing.

```
/go:retro {ISSUE_NUMBER}
```
Reviews specific issue.
