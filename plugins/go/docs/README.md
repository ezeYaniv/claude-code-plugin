# Personal Claude Code Plugin (v2.0)

Unified workflow commands for personal projects. Uses **subagents** for isolated implementation and review, **hooks** for automation, and **dynamic context injection** for zero-waste status detection.

## Installation

### For Repos Already Configured

If your repo already has the plugin configured in `.claude/settings.json`, just set up your GitHub token:

```bash
brew install gh
gh auth login
echo 'export GITHUB_TOKEN=$(gh auth token)' >> ~/.zshrc
source ~/.zshrc
```

### For New Repos

1. Set up GitHub token (see above)
2. In Claude Code: `/plugin -> Marketplaces -> Add Marketplace -> ezeYaniv/claude-code-plugin`
3. Install: `/plugin -> Install -> go@ezeYaniv`
4. Select "Install for all users" to add to repo settings

## Usage

Start any issue with:
```
/go:go {ISSUE_NUMBER}
```

The orchestrator handles the rest - planning, implementation (via `eng` subagent), review (via `rev` subagent), and finalization.

See [workflow.md](workflow.md) for the full state machine, iteration loops, and a typical session walkthrough.

## Components

### Skills (run in main context)

| Command | Description |
|---------|-------------|
| `/go:go` | Orchestrator - coordinates workflow, spawns subagents |
| `/go:status` | Show current state (shell script via DCI) |
| `/go:plan` | Create implementation plan (Plan Mode) |
| `/go:pm` | Issue management and decomposition |
| `/go:finalize` | Commit, push, and PR creation |
| `/go:worktree` | Manage git worktrees for parallel development |
| `/go:pr-review` | Review another dev's PR (forked context) |
| `/go:learn` | Update plugin with feedback |
| `/go:retro` | Extract learnings from completed work |

### Subagents (isolated context per invocation)

| Agent | Description |
|-------|-------------|
| `eng` | TDD Engineer - implements code with fresh context each iteration (`memory: project`) |
| `rev` | Code Reviewer - reviews with fresh context each iteration (`memory: user`) |

Subagents are internal — they are spawned automatically by `/go:go` and should not be invoked directly. The orchestrator manages their lifecycle, passes them the right context (issue, plan, review feedback), and routes based on their results.

### Hidden Skills

| Skill | Description |
|-------|-------------|
| `testing-standards` | Shared anti-patterns preloaded into eng + rev subagents |

### Hooks

| Hook | Event | Description |
|------|-------|-------------|
| `approve-setup-commands.sh` | PreToolUse (Bash) | Auto-approves safe setup commands during worktree operations |
| `worktree-create.sh` | WorktreeCreate | Creates git worktree, copies config files, registers plugins, adds to VSCode Project Manager |
| `post-plan-mode.sh` | PostToolUse (ExitPlanMode) | Persists plan to `.claude/issues/{ISSUE}.plan.md` after approval |

**Known issue:** Plugin `PostToolUse` hooks don't reliably fire. The `post-plan-mode.sh` hook should also be added to `~/.claude/settings.json` until Anthropic fixes this:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "ExitPlanMode",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/plugins/cache/ezeYaniv/go/2.0.0/scripts/post-plan-mode.sh"
          }
        ]
      }
    ]
  }
}
```

## How Updates Work

**IMPORTANT: Bump the version in `.claude-plugin/plugin.json` with every change.** Claude Code uses the version to decide whether to update the cache. If you don't bump it, users won't see your changes.

1. Make changes on a feature branch
2. Bump version in `.claude-plugin/plugin.json`
3. Merge to main
4. Updates are available on next `/go:go` (startup pulls latest)

## Key Architecture Decisions (v2.0)

- **eng and rev are subagents**, not skills — each iteration gets a fresh context window with standards at the top, not buried under thousands of tokens of previous output
- **Subagent memory** — eng accumulates project-specific patterns, rev accumulates review intelligence across all projects
- **testing-standards is a shared skill** preloaded into both subagents — single source of truth, no duplication
- **Status uses a shell script** via DCI — zero LLM tokens for deterministic git/file operations
- **PreToolUse hooks** auto-approve safe bash commands during worktree setup
- **WorktreeCreate hook** replaces default git worktree behavior for reliable worktree creation
- **Plan persistence** has two layers of defense — PostToolUse hook writes it after approval, go.md verifies it exists

## Conventions

| Item | Standard |
|------|----------|
| Plan directory | `.claude/issues/` |
| Branch format | `feature/{ISSUE_NUMBER}_description` or `bugfix/{ISSUE_NUMBER}_description` |
| Plan structure | `<!-- SPECIFICATION -->` + `<!-- IMPLEMENTATION -->` markers |

## Contributing Improvements

When Claude learns something, it updates this repo:

1. `/go:learn "Always check for X"` - immediate learning
2. `/go:retro` after completing work - systematic review

Both commands:
- Pull latest plugin
- Make the update
- Show diff for approval
- Commit and push if approved

## Project-Specific Configuration

Each project keeps a minimal `CLAUDE.md` with:
- Quick start command
- Project-specific test commands
- Key directories
- Tech stack summary

Detailed standards go in `.claude/` files (project.md, standards.md, testing.md). The workflow commands come from this plugin.
