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
/plugin → Marketplaces → Add Marketplace → ezeYaniv/claude-code-plugin
```

3. Install the plugin:
```
/plugin → Install → go@ezeYaniv
```

4. Select "Install for all users" to add to your repo settings.

### Usage

Start working on any GitHub issue:
```
/go:go {ISSUE_NUMBER}
```

The orchestrator handles everything:
- Plans the implementation
- Implements using TDD
- Reviews and iterates automatically
- Commits and pushes when ready

## How It Works

The `go` plugin implements a state machine workflow:

```
no-issue → needs-plan → needs-approval → implementing ⇄ reviewing → approved → finalized
                              ↓                              ↓
                        (user reviews)              (auto iteration loop)
```

### Human Involvement

You only need to intervene at two points:
1. **Plan approval** - Review and approve the implementation plan
2. **Plan revision** - When fundamental issues require replanning

Everything else runs automatically, including the implementation-review iteration loop.

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
    plugin.json            # Plugin metadata
  commands/
    go.md                  # Main orchestrator
    plan.md                # Planning workflow
    eng.md                 # TDD implementation
    rev.md                 # Code review
    pm.md                  # Issue management
    finalize.md            # Commit and push
    pr-review.md           # PR review
    learn.md               # Immediate learning
    retro.md               # Post-issue learning
    status.md              # State inspection
  docs/
    README.md              # Plugin documentation
    workflow.md            # State machine details
```

## Available Commands

| Command | Purpose | User Interaction |
|---------|---------|------------------|
| `/go:go {NUM}` | Orchestrate full workflow | Approves plan |
| `/go:plan` | Create implementation plan | Reviews plan |
| `/go:eng` | Implement using TDD | None (automatic) |
| `/go:rev` | Review implementation | None (automatic) |
| `/go:pm` | Manage and decompose issues | As needed |
| `/go:finalize` | Commit and push | None |
| `/go:pr-review` | Review someone else's PR | Provides feedback |
| `/go:learn` | Update plugin with feedback | Approves changes |
| `/go:retro` | Extract learnings | Approves updates |
| `/go:status` | Show current state | None |

## Workflow Details

### The Iteration Loop

When `/go:rev` finds fixable issues, it automatically triggers `/go:eng` to fix them. This continues until:
- All issues are resolved (moves to `approved`)
- Issues require plan changes (moves to `needs-revision`)

You're not involved in this loop - it runs automatically.

### Conventions

- **Plans**: Stored in `.claude/issues/{NUM}.plan.md`
- **Branches**: `feature/{NUM}_description` or `bugfix/{NUM}_description`
- **Plan Structure**: Uses `<!-- SPECIFICATION -->` and `<!-- IMPLEMENTATION -->` markers
- **Updates**: Auto-pulled on each `/go:go` execution

## Project-Specific Setup

Each project using this plugin should have a `CLAUDE.md` file with:
- Quick start command
- Test commands
- Key directories
- Tech stack summary

The workflow commands come from this plugin repository.

### Optional: Custom Status Line

This repository includes a custom status line script that displays:
- Issue number (extracted from branch names like `feature/123_description`)
- Current branch name
- Model being used (opus/sonnet/haiku)
- Context window usage percentage
- Recent prompts with contextual icons

To use it in a project:

1. Copy the status line script to your project:
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

The status line will automatically display issue numbers extracted from your branch names (format: `feature/123_description` or `bugfix/456_description`).

## Contributing

This is a personal plugin repository, but the self-learning system means it evolves based on actual usage:

1. During work: `/go:learn "pattern to remember"`
2. After completion: `/go:retro` to extract systematic learnings
3. Approve the suggested updates
4. Changes are committed and available on next `/go:go`

## Requirements

- Claude Code CLI
- GitHub CLI (`gh`) with authentication
- Git repository with GitHub issues

## Documentation

- [Plugin Documentation](plugins/go/docs/README.md) - Installation and setup
- [Workflow Details](plugins/go/docs/workflow.md) - State machine and iteration loops
- Individual command files in [plugins/go/commands/](plugins/go/commands/)

## License

Personal use.
