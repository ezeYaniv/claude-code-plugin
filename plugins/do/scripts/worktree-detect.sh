#!/usr/bin/env bash
# Detect worktree state for a given issue number.
# Usage: worktree-detect.sh [ISSUE_NUMBER]
# Outputs key=value pairs for the orchestrator to parse.
set -euo pipefail

ISSUE="${1:-}"

# --- Detect worktree vs main repo ---
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")

if [ "$GIT_DIR" != "$GIT_COMMON_DIR" ]; then
  IS_WORKTREE=true
else
  IS_WORKTREE=false
fi

# Extract issue number from current branch
CURRENT_ISSUE=""
if [[ "$BRANCH" =~ ^(feature|bugfix)/([0-9]+) ]]; then
  CURRENT_ISSUE="${BASH_REMATCH[2]}"
elif [[ "$BRANCH" =~ ^([0-9]+) ]]; then
  CURRENT_ISSUE="${BASH_REMATCH[1]}"
fi

# --- Determine result ---

if $IS_WORKTREE; then
  # We're in a worktree
  if [ -z "$ISSUE" ] || [ "$ISSUE" = "$CURRENT_ISSUE" ]; then
    echo "result=in-worktree"
    echo "ticket=$CURRENT_ISSUE"
    echo "branch=$BRANCH"
    echo "action=proceed"
  else
    echo "result=in-worktree"
    echo "ticket=$CURRENT_ISSUE"
    echo "branch=$BRANCH"
    echo "requested=$ISSUE"
    echo "action=mismatch"
  fi
elif [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  # Main repo on main/master — check if worktree exists for issue
  if [ -z "$ISSUE" ]; then
    echo "result=main-repo"
    echo "branch=$BRANCH"
    echo "action=no-ticket"
  else
    EXISTING_PATH=$(git worktree list | grep "$ISSUE" | awk '{print $1}' || true)
    if [ -n "$EXISTING_PATH" ]; then
      echo "result=has-worktree"
      echo "ticket=$ISSUE"
      echo "path=$EXISTING_PATH"
      echo "action=switch"
    else
      echo "result=needs-worktree"
      echo "ticket=$ISSUE"
      echo "action=setup"
    fi
  fi
else
  # Main repo on a feature branch
  echo "result=on-feature-branch"
  echo "ticket=$CURRENT_ISSUE"
  echo "branch=$BRANCH"
  echo "action=proceed"
fi
