# Learn

Update Claude configuration based on feedback. Automatically routes to the right place.

## Purpose

Make corrections and preferences permanent.

## Learning Categories

Automatically categorize each learning:

**Universal (→ plugin):**
- Workflow improvements (orchestration, state machine)
- TDD patterns and anti-patterns
- Review process improvements
- Planning structure changes
- Cross-project conventions

**Project-Specific (→ project's .claude/ files):**
- Directory layout conventions
- Project-specific test patterns
- Tech stack specifics
- Naming conventions unique to this codebase
- Security patterns specific to this project

## Process

1. **Parse feedback** - What should Claude do differently?
2. **Categorize** - Universal or project-specific?
3. **Identify target file:**

   **If Universal (plugin):**
   - `commands/eng.md` - Engineering workflow
   - `commands/rev.md` - Review process
   - `commands/plan.md` - Planning
   - `commands/go.md` - Orchestration
   - `commands/pm.md` - PM/decompose
   - `commands/finalize.md` - Finalization
   - `commands/status.md` - Status detection

   **If Project-Specific (project's .claude/):**
   - `project.md` - Directory layout, tech stack
   - `standards.md` - Code style, security, git practices
   - `testing.md` - Project-specific test patterns

4. **Make update** - Concise, actionable language
5. **Show diff** - Present change to user
6. **Confirm** - Apply the change

## Handling by Category

### Project-Specific Learnings

Update the project's `.claude/` files directly. These changes will be:
- Included in the current branch
- Part of the PR when finalized
- Committed with the related code changes

```bash
# Edit project's .claude/standards.md (or testing.md, project.md)
# Changes stay uncommitted until finalize
```

### Universal Learnings

Update plugin repo:

```bash
# Locate plugin
git -C ~/.claude/plugins/marketplaces/ezeYaniv pull
# Make edit to target command file
git -C ~/.claude/plugins/marketplaces/ezeYaniv diff
# Commit and push
git -C ~/.claude/plugins/marketplaces/ezeYaniv add -A
git -C ~/.claude/plugins/marketplaces/ezeYaniv commit -m "learn: {brief description}"
git -C ~/.claude/plugins/marketplaces/ezeYaniv push
```

## Usage

```
/go:learn Always run black before committing Python
```
→ Project-specific → updates project's standards.md

```
/go:learn When reviewing, check for the N+1 query anti-pattern
```
→ Universal → updates plugin/commands/rev.md

```
/go:learn E2E tests should use data-testid not class selectors
```
→ Could be either - if it's a project convention → project's testing.md; if it's universal best practice → plugin/commands/eng.md

## Writing Style

- Be concise - one line if possible
- Be actionable - Claude knows exactly what to do
- Be specific - avoid vague guidance
- Match existing file tone

**Good:** "Use `data-testid` attributes for E2E selectors, not CSS classes"
**Bad:** "Write better tests"

## After Update

Report:
- Category (universal/project-specific)
- Which file updated
- What was added/changed
- For universal: confirm pushed to plugin
- For project-specific: note it will be committed with finalize
