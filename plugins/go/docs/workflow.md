# Workflow Overview

## Architecture (v2.0)

The plugin uses three types of components:

| Component | Type | Context | Purpose |
|-----------|------|---------|---------|
| `go` | Skill (command) | Main thread | Orchestrator — routes state, spawns subagents |
| `plan` | Skill (command) | Main thread | Architect — Plan Mode research + approval |
| `eng` | **Subagent** | **Isolated** | TDD implementation (fresh context each iteration) |
| `rev` | **Subagent** | **Isolated** | Code review (fresh context each iteration) |
| `pr-review` | Skill (forked) | **Isolated** | External PR review (context: fork) |
| `pm` | Skill (command) | Main thread | Product management, decomposition |
| `status` | Skill (DCI) | Main thread | Shell script via dynamic context injection |
| `finalize` | Skill (command) | Main thread | Commit, push, PR creation |
| `worktree` | Skill (command) | Main thread | Git worktree management |
| `learn` | Skill (command) | Main thread | Feedback integration |
| `retro` | Skill (command) | Main thread | Post-issue learning extraction |
| `testing-standards` | Skill (hidden) | Preloaded | Shared anti-patterns for eng + rev |

**Key insight:** `eng` and `rev` run as subagents with isolated context windows. Each iteration starts fresh with standards at the top of context, not buried under previous tool calls. The orchestrator only receives summaries back.

## State Machine

```
                    +------------------+
                    |    no-issue      |
                    +--------+---------+
                             | /go:go {ISSUE_NUMBER}
                             v
                    +------------------+
                    |   needs-plan     |
                    +--------+---------+
                             | /go:plan (Plan Mode)
                             v
                    +------------------+
              +---->| needs-approval   |<----+
              |     +--------+---------+     |
              |              | user approves |
              |              v               |
              |     +------------------+     |
              |     |  implementing    |     |
              |     +--------+---------+     |
              |              | eng subagent  |
              |              v               |
              |     +------------------+     |
              |     |   reviewing      |     |
              |     +--------+---------+     |
              |              | rev subagent  |
              |              v               |
              |     +------------------+     |
   plan needs |     |   iterating      |-----+
   revision   |     +--------+---------+ fixable issues
              |              | (auto loop — fresh subagents)
              |              v
              |     +------------------+
              +-----|  needs-revision   |
                    +------------------+
                             |
            (when approved)  |
                             v
                    +------------------+
                    |    approved      |
                    +--------+---------+
                             | /go:finalize
                             v
                    +------------------+
                    |   finalized      |
                    +------------------+
```

## Human Breakpoints

The workflow stops and waits for human input at these points:

1. **Plan Mode approval** - During `/go:plan`, the Architect enters Plan Mode (system-enforced read-only). User approves the plan via Plan Mode's built-in approval. This IS the plan approval — no separate `needs-approval` step needed.
2. **needs-approval** - Only hit during revision flow (reviewer sends plan back). User reviews revised plan.
3. **needs-revision** - Reviewer found issues requiring plan changes

Everything else is automatic - the eng <-> rev loop iterates without user involvement.

## The Iteration Loop

When reviewer finds fixable issues, fresh subagents are spawned for each iteration:

```
eng subagent reads review, fixes issues (fresh context)
    |
eng marks implementation complete
    |
rev subagent re-reviews (fresh context)
    |
(repeat until approved or needs-revision)
```

**User is NOT involved in this loop.** Only plan-level issues stop the loop.

**Why subagents:** Each iteration gets a fresh context window with project standards and testing anti-patterns at the top. The orchestrator's context stays lean — it only sees summaries.

## Subagent Memory

- **eng** has `memory: project` — accumulates project-specific patterns (test naming, import style, etc.)
- **rev** has `memory: user` — accumulates review intelligence across all projects

Both preload the `testing-standards` skill at startup for shared anti-pattern knowledge.

## Hooks

The plugin includes hooks (`hooks/hooks.json`) that:
- **PreToolUse (Bash):** Auto-approve safe setup commands (git, npm, poetry, file copies, etc.)
- **WorktreeCreate:** Create git worktree, copy config, install deps, register plugins, open VSCode
- **PostToolUse (ExitPlanMode):** Persist plan to `.claude/issues/{ISSUE}.plan.md` after approval

## Dynamic Context Injection

- `go.md` injects status via `!scripts/status.sh` — no LLM tokens wasted on deterministic git/file parsing
- `plan.md` injects the current issue from branch name
- `status.md` injects the full status report via the shell script

## Plan Persistence

After Plan Mode approval, the plan is written to `.claude/issues/{ISSUE_NUMBER}.plan.md`. The orchestrator has a safety check: if the plan skill fails to persist it, the orchestrator reads the system plan file and writes it itself.

## Learning Loop

Two mechanisms for improving the workflow:

### Immediate Learning (`/go:learn`)

When user corrects behavior mid-session:
1. Apply correction immediately
2. Identify pattern
3. Suggest permanent update to plugin
4. If approved, commit and push

### Post-Issue Learning (`/go:retro`)

After completing work:
1. Review plan and review files
2. Identify patterns from iterations
3. Propose updates to plugin
4. If approved, commit and push

## Typical Session

```
User: /go:go 123

Claude: [updates plugin]
        [reads DCI status output]
        State: needs-plan
        Running /go:plan...
        Entering Plan Mode (system-enforced read-only)...

Claude: [fetches GitHub issue context via gh]
        [explores codebase — read-only enforced]
        [writes full plan to system plan file]
        Exiting Plan Mode. Plan ready for review.

User: [reviews plan in Plan Mode UI, approves]

Claude: [writes approved plan to .claude/issues/123.plan.md]
        Spawning eng subagent...
        [eng implements using TDD in isolated context]
        eng complete. Spawning rev subagent...
        [rev reviews in isolated context]
        Iterate - found 2 issues
        Spawning eng subagent (iteration 2)...
        [eng fixes issues in fresh context]
        Spawning rev subagent (iteration 2)...
        Approved
        Ready for /go:finalize

User: Finalize it.

Claude: [runs /go:retro]
        No learnings identified.
        [commits and pushes]
        Branch pushed. Creating PR...
        PR created: https://github.com/...
```

## Parallel Development

Work on multiple issues simultaneously using git worktrees.

### Workflow

```
Main repo (main)                   Worktree (#123)
      |                                  |
      +-- /go:go 123                     |
      |   [creates worktree]             |
      |   [opens VS Code] ------------->|
      |                                  +-- claude
      |                                  +-- /go:go 123
      |                                  +-- (normal workflow)
      |                                  +-- /go:finalize
      |<---------------------------------+ [cleanup]
```

### How It Works

1. Run `/go:go {ISSUE_NUMBER}` from main repo on `main` branch
2. Claude automatically creates a worktree at `.claude/worktrees/{ISSUE_NUMBER}`
3. If VS Code `code` command is available, opens worktree in a new VS Code window
4. Open a terminal in the worktree directory and run `claude` to start working
5. On `/go:finalize`, settings sync back and worktree is cleaned up

### Managing Worktrees

| Command | Description |
|---------|-------------|
| `/go:worktree list` | See all active worktrees |
| `/go:worktree sync` | Sync settings from main repo |
| `/go:worktree cleanup {ISSUE_NUMBER}` | Manual cleanup |

### Settings That Sync

These files are copied to worktrees and synced back on cleanup:
- `.env` - Environment variables and secrets
- `.claude/settings.local.json` - Local Claude permissions and hooks
