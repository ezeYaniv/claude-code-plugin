#!/usr/bin/env bash
# PreToolUse hook for auto-approving safe worktree/setup bash commands.
# Reads tool input JSON from stdin. Outputs permission decision JSON.
# If command matches the allowlist, outputs permissionDecision: "allow".
# If command does NOT match, outputs nothing (falls through to normal permission handling).
set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

if [ -z "$COMMAND" ]; then
  exit 0
fi

# --- Allowlist patterns ---
# Each pattern is checked against the command. If ANY pattern matches, auto-approve.

APPROVE=false

# Git read-only / worktree operations
if echo "$COMMAND" | grep -qE '^git (worktree (add|remove|list)|fetch|branch|rev-parse|status|log|diff|remote|show-current|ls-files)'; then
  APPROVE=true
fi

# npm/poetry install (dependency setup)
if echo "$COMMAND" | grep -qE '^(npm install|poetry install)'; then
  APPROVE=true
fi

# Python venv management
if echo "$COMMAND" | grep -qE '^(deactivate|unset VIRTUAL_ENV)'; then
  APPROVE=true
fi

# Copy config files (.env, settings)
if echo "$COMMAND" | grep -qE '^\[.*cp.*\.(env|settings)'; then
  APPROVE=true
fi
if echo "$COMMAND" | grep -qE '^cp .*(\.env|settings\.local\.json)'; then
  APPROVE=true
fi

# Conditional file copy patterns from worktree.md ([ -f ".env" ] && cp ...)
if echo "$COMMAND" | grep -qE '^\[ -f .*\] && cp'; then
  APPROVE=true
fi

# jq operations on plugin/project manager JSON files
if echo "$COMMAND" | grep -qE '^(jq|UPDATED=.*jq|echo.*jq).*\.(json)'; then
  APPROVE=true
fi

# VS Code open
if echo "$COMMAND" | grep -qE '^(code -n|command -v code)'; then
  APPROVE=true
fi

# Directory creation
if echo "$COMMAND" | grep -qE '^mkdir -p'; then
  APPROVE=true
fi

# Git plugin update commands from go.md startup
if echo "$COMMAND" | grep -qE '^git -C.*plugins/marketplaces.*fetch'; then
  APPROVE=true
fi
if echo "$COMMAND" | grep -qE '^git -C.*plugins/marketplaces.*reset --hard origin/main'; then
  APPROVE=true
fi

# IS_WORKTREE detection pattern
if echo "$COMMAND" | grep -qE '^IS_WORKTREE='; then
  APPROVE=true
fi

# Check for gh CLI availability
if echo "$COMMAND" | grep -qE '^(command -v gh|which gh|gh issue view)'; then
  APPROVE=true
fi

# Plugin script execution (status.sh, worktree-detect.sh, etc.)
if echo "$COMMAND" | grep -qE '(status|worktree-detect)\.sh'; then
  APPROVE=true
fi

# --- Decision ---
if $APPROVE; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Auto-approved by go plugin: safe setup/read command"
  }
}
EOF
fi

# If not approved, output nothing — falls through to normal permission handling
exit 0
