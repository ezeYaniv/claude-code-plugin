# Claude Code Plugin Repository

Personal workflow automation plugins for Claude Code - a state machine-driven development system that handles planning, implementation, review, and finalization.

## What This Is

This repository contains Claude Code plugins that automate software development workflows. The main plugin (`go`) provides a complete issue-to-PR workflow with automatic iteration loops, TDD implementation, and self-learning capabilities.

## Quick Start

### Installation

1. Set up GitHub authentication:
```bash
brew install gh
gh auth login
echo 'export GITHUB_TOKEN=$(gh auth token)' >> ~/.zshrc
source ~/.zshrc
```

2. In Claude Code, add this marketplace:
```
/plugin -> Marketplaces -> Add Marketplace -> ezeYaniv/claude-code-plugin
```

3. Install the plugin:
```
/plugin -> Install -> go@ezeYaniv
```

4. Select "Install for all users" to add to your repo settings.

### Usage

Start working on any GitHub issue:
```
/go:go {ISSUE_NUMBER}
```

The orchestrator handles everything:
- Plans the implementation (Plan Mode)
- Spawns engineer subagent for TDD implementation
- Spawns reviewer subagent for code review
- Iterates automatically until approved
- Commits, pushes, and creates PR when ready

## How It Works

The `go` plugin implements a state machine workflow:

```
no-issue -> needs-plan -> needs-approval -> implementing <-> reviewing -> approved -> finalized
                              |                              |
                        (user reviews)              (auto iteration loop)
```

### Human Involvement

You only need to intervene at two points:
1. **Plan approval** - Review and approve the implementation plan (in Plan Mode)
2. **Plan revision** - When fundamental issues require replanning

Everything else runs automatically, including the implementation-review iteration loop using isolated subagents.

### Architecture (v2.0)

- **eng and rev are subagents** - each iteration gets a fresh context window with standards at the top
- **testing-standards** is a shared skill preloaded into both subagents
- **Status uses a shell script** via DCI - zero LLM tokens for deterministic state detection
- **Hooks** auto-approve safe commands, create worktrees, and persist plans

### Self-Learning System

The plugin improves itself over time:

- `/go:learn "pattern"` - Immediate feedback during work
- `/go:retro` - Post-issue review and extraction of learnings

Both commands update this repository automatically when you approve changes.

## Repository Structure

```
.claude/
  status_line.py           # Custom status line script (optional)

.claude-plugin/
  marketplace.json          # Plugin marketplace configuration

plugins/go/
  .claude-plugin/
    plugin.json            # Plugin metadata + version
  commands/                # Skills (markdown prompts invoked via /go:<name>)
    go.md                  # Orchestrator - state machine, subagent spawning
    plan.md                # Architect - Plan Mode research + spec writing
    finalize.md            # Commit, push, PR creation
    pm.md                  # Issue management and decomposition
    worktree.md            # Git worktree management
    learn.md               # Feedback integration
    retro.md               # Post-issue learning extraction
    pr-review.md           # External PR review
    status.md              # DCI shell script status display
    testing-standards.md   # Hidden skill preloaded into eng + rev
  agents/                  # Subagent definitions (spawned by orchestrator)
    eng.md                 # TDD Engineer (memory: project, model: sonnet)
    rev.md                 # Code Reviewer (memory: user, model: sonnet)
  hooks/
    hooks.json             # Hook definitions (PreToolUse, WorktreeCreate, PostToolUse)
  scripts/                 # Shell scripts for hooks and DCI
    status.sh              # Deterministic status detection
    worktree-create.sh     # WorktreeCreate hook
    worktree-detect.sh     # Worktree state detection for orchestrator routing
    approve-setup-commands.sh  # PreToolUse hook - auto-approves safe bash commands
    post-plan-mode.sh      # PostToolUse hook - persists plan after ExitPlanMode
  docs/
    README.md              # Plugin documentation
    workflow.md            # State machine diagram, architecture, session walkthrough
```

## Components

### Skills (run in main context)

| Command | Description |
|---------|-------------|
| `/go:go` | Orchestrator - coordinates workflow, spawns subagents |
| `/go:status` | Show current state (shell script via DCI) |
| `/go:plan` | Create implementation plan (Plan Mode) |
| `/go:pm` | Issue management and decomposition |
| `/go:finalize` | Commit, push, PR creation |
| `/go:worktree` | Manage git worktrees |
| `/go:pr-review` | Review another dev's PR |
| `/go:learn` | Update plugin with feedback |
| `/go:retro` | Extract learnings from completed work |

### Subagents (isolated context per invocation)

| Agent | Description |
|-------|-------------|
| `eng` | TDD Engineer - fresh context each iteration (`memory: project`) |
| `rev` | Code Reviewer - fresh context each iteration (`memory: user`) |

## Conventions

- **Plans**: Stored in `.claude/issues/{NUM}.plan.md`
- **Branches**: `feature/{NUM}_description` or `bugfix/{NUM}_description`
- **Plan Structure**: Uses `<!-- SPECIFICATION -->` and `<!-- IMPLEMENTATION -->` markers
- **Updates**: Auto-pulled on each `/go:go` execution
- **Version**: Bump `.claude-plugin/plugin.json` version with every change

## Project-Specific Setup

Each project using this plugin should have a `CLAUDE.md` file with:
- Quick start command
- Test commands
- Key directories
- Tech stack summary

Detailed standards go in `.claude/` files (project.md, standards.md, testing.md).

### Optional: Custom Status Line

This repository includes a custom status line script. To use it in a project:

1. Copy the status line script:
```bash
mkdir -p .claude
curl -o .claude/status_line.py https://raw.githubusercontent.com/ezeYaniv/claude-code-plugin/main/.claude/status_line.py
chmod +x .claude/status_line.py
```

2. Add to your project's `.claude/settings.json`:
```json
{
  "statusLine": {
    "command": "python3 .claude/status_line.py"
  }
}
```

## Requirements

- Claude Code CLI
- GitHub CLI (`gh`) with authentication
- Git repository with GitHub issues

## Documentation

- [Plugin Documentation](plugins/go/docs/README.md) - Installation and setup
- [Workflow Details](plugins/go/docs/workflow.md) - State machine and iteration loops

## License

Personal use.
