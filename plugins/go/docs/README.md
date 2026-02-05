# Personal Claude Code Plugin

Unified workflow commands for personal projects.

## Installation

### For Developers (repos already configured)

If your repo already has the plugin configured in `.claude/settings.json`, just set up your GitHub token:

```bash
brew install gh
gh auth login
echo 'export GITHUB_TOKEN=$(gh auth token)' >> ~/.zshrc
source ~/.zshrc
```

### For New Repos

1. Set up GitHub token (see above)
2. In Claude Code: `/plugin → Marketplaces → Add Marketplace → ezeYaniv/claude-code-plugin`
3. Install: `/plugin → Install → go@ezeYaniv`
4. Select "Install for all users" to add to repo settings

## Usage

Start any issue with:
```
/go:go {ISSUE_NUMBER}
```

The orchestrator handles the rest - planning, implementation, review, and finalization.

See [workflow.md](workflow.md) for the full state machine, iteration loops, and a typical session walkthrough.

## Available Commands

| Command | Description |
|---------|-------------|
| `/go:go` | Orchestrator - coordinates workflow |
| `/go:status` | Show current state |
| `/go:plan` | Create implementation plan |
| `/go:eng` | Implement using TDD |
| `/go:rev` | Review implementation |
| `/go:pm` | Issue management and decomposition |
| `/go:finalize` | Commit and push |
| `/go:worktree` | Manage git worktrees for parallel development |
| `/go:pr-review` | Review another dev's PR |
| `/go:learn` | Update plugin with feedback |
| `/go:retro` | Extract learnings from completed work |

## How Updates Work

1. `/go:go` clears plugin cache and pulls latest from GitHub at startup
2. `/go:learn` and `/go:retro` push improvements to this repo
3. Updates are available on next `/go:go`

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

The workflow commands come from this plugin.
