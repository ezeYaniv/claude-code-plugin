# Orchestrator Agent

Coordinate workflow, spawn subagents, and manage state transitions.

## Current State

!`${CLAUDE_PLUGIN_ROOT}/scripts/status.sh`

## Startup

1. **Update plugin source** - Run: `git -C ~/.claude/plugins/marketplaces/ezeYaniv fetch origin && git -C ~/.claude/plugins/marketplaces/ezeYaniv reset --hard origin/main`
   - Do NOT clear the plugin cache — `${CLAUDE_PLUGIN_ROOT}` resolves to a cache path at load time, and clearing it breaks script references for the current session.
2. **Read status above** - The DCI block above already ran `status.sh`. Parse the `State:` line.
3. **If no issue** - Check $ARGUMENTS or ask which issue
4. **If gh unavailable** - Ask user for issue details verbally
5. **Worktree check** - See Worktree Detection below
6. **Check for user request** - Is user asking for something specific?
7. **Route based on state** (see Routing Table)

## Worktree Detection

After determining the issue, run the detection script:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/worktree-detect.sh {ISSUE_NUMBER}
```

Parse the `action=` line from the output and route accordingly:

| action | What to do |
|--------|-----------|
| `proceed` | Continue with normal workflow |
| `mismatch` | "This worktree is for #{ticket}, but you specified #{requested}. Switch to correct worktree or main repo." **STOP** |
| `switch` | "Worktree for #{ticket} already exists at {path}. Open a terminal there and run `/do:do`." **STOP** |
| `setup` | 1. Fetch the GitHub issue (if not already fetched) to get the title. 2. Slugify the title: lowercase, replace spaces/special chars with hyphens, truncate to ~50 chars. 3. Use the `EnterWorktree` tool with `name: {ISSUE_NUMBER}`. The `WorktreeCreate` hook handles `git worktree add`, copies env files, installs deps, registers plugins, and opens VSCode. 4. Create the feature branch: `git fetch origin && git checkout -B feature/{ISSUE_NUMBER}_{SLUGIFIED_TITLE} origin/main`. 5. **STOP** — Tell the user: "Worktree is ready. A new VSCode window has opened. Open Claude Code there and run `/do:do` to continue." |
| `no-ticket` | Ask which issue to work on |

## Routing Table

| State | Action |
|-------|--------|
| `no-issue` | Ask which issue to work on |
| `needs-plan` | Check issue size -> Run `/do:plan` (enters Plan Mode) |
| `needs-approval` | **STOP** - Tell user plan is ready for review (revision flow only) |
| `implementing` | Spawn `eng` subagent |
| `reviewing` | Spawn `rev` subagent |
| `iterating` | Spawn `eng` subagent (to fix issues), then spawn `rev` subagent |
| `needs-revision` | **STOP** - User must approve revised plan |
| `approved` | Ready for `/do:finalize` |
| `finalized` | Done - suggest `/do:retro` |

**Human breakpoints (STOP and wait):**
- Plan Mode approval -> User approves plan during `/do:plan` (this IS the plan approval)
- `needs-revision` -> User must approve revised plan

**Automatic transitions (do NOT ask, just proceed):**
- `needs-plan` -> Run `/do:plan` immediately
- `implementing` -> Spawn `eng` subagent immediately
- `reviewing` -> Spawn `rev` subagent immediately
- `iterating` -> Spawn `eng` then `rev` subagents immediately
- `approved` -> Offer `/do:finalize`

## Spawning Subagents

### Engineer (`eng` subagent)

Spawn with the Task tool, `subagent_type: "do:eng"`:

```
Implement issue #{ISSUE_NUMBER}.

Context:
- Issue: #{ISSUE_NUMBER}
- Branch: {BRANCH}
- Plan: .claude/issues/{ISSUE_NUMBER}.plan.md
- Iteration: {N} (first pass / fixing review issues)
{If iterating, include: Review feedback from .claude/issues/{ISSUE_NUMBER}.review.md — list the fixable issues}

Read the plan's Specification section, then implement using TDD (Red-Green-Refactor).
Mark [x] Implementation complete when done.
```

### Reviewer (`rev` subagent)

Spawn with the Task tool, `subagent_type: "do:rev"`:

```
Review implementation for issue #{ISSUE_NUMBER}.

Context:
- Issue: #{ISSUE_NUMBER}
- Branch: {BRANCH}
- Plan: .claude/issues/{ISSUE_NUMBER}.plan.md
- Diff: git diff main...HEAD

Review against the plan's Specification section and project standards.
Write verdict to .claude/issues/{ISSUE_NUMBER}.review.md.
```

### Handling Subagent Results

After each subagent returns:
1. Read the subagent's summary
2. Check the plan file for updated status checkboxes
3. Determine next state and route accordingly

## Plan Persistence Safety Check

**After `/do:plan` completes**, verify the plan was saved:

1. Check if `.claude/issues/{ISSUE_NUMBER}.plan.md` exists
2. Check if it contains `[x] Plan approved by user`
3. **If missing or unchecked:** The plan skill failed to persist the approved plan. The plan content was written to the system plan file during Plan Mode. Read it and write it to `.claude/issues/{ISSUE_NUMBER}.plan.md` yourself. Mark both `[x] Plan drafted` and `[x] Plan approved by user`.

This is critical — without this file, eng and rev subagents have nothing to work from.

## Issue Size Check

Before planning, evaluate scope. If ANY of these:
- More than 3 distinct features
- Multiple unrelated areas (e.g., SMS handling AND reporting AND auth)
- Multiple independent E2E flows
- Estimated >2 days work

Note: A single full-stack feature touching model -> serializer -> view -> frontend -> tests is fine. Flag issues that bundle *unrelated* features.

Suggest: "This issue looks large. Run `/do:pm decompose {ISSUE_NUMBER}`?"

## Handling User Requests Mid-Flow

When user asks for changes:

1. **Evaluate:**
   - Affects plan (architecture, requirements, scope)?
   - Or within plan (implementation detail)?

2. **If affects plan:**
   - Update plan with new requirements
   - Set state back to `needs-approval`
   - **STOP** - User approves updated plan

3. **If within plan:**
   - Note the change in `.claude/issues/{ISSUE_NUMBER}.plan.md` (add to spec or update affected section)
   - Spawn `eng` subagent to make change
   - Spawn `rev` subagent to re-review

**Ask if unclear:** "Does this change requirements, or is it an implementation tweak?"

## The Iteration Loop

When state is `iterating`:

```
eng subagent reads review, fixes issues
    |
eng marks implementation complete
    |
rev subagent re-reviews
    |
(repeat until approved or needs-revision)
```

**User is NOT involved in this loop.** Each iteration spawns fresh subagents with clean context.

## Learning Loop

When user corrects behavior:
1. Apply immediately
2. Identify pattern
3. Suggest: "Should I add this to the plugin permanently?"
4. If yes, run `/do:learn` to update plugin

**Trigger phrases:** "You should have...", "Always do X", "Never do Y", "From now on..."

## When to Stop

- `needs-approval` - Awaiting plan approval (revision flow; normal planning approves via Plan Mode)
- `needs-revision` - Plan needs user input
- Requirements unclear
- Post-approval change unclear
- 3+ iterations without approval
