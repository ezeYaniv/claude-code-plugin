#!/usr/bin/env bash
# WorktreeCreate hook — replaces default git worktree behavior.
# Creates the git worktree, copies config files, installs dependencies, registers plugins, adds to VSCode Project Manager.
# Must print the absolute worktree path to stdout on success.
set -euo pipefail

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')
CWD=$(echo "$INPUT" | jq -r '.cwd')

WORKTREE_PATH="${CWD}/.claude/worktrees/${NAME}"
REPO_NAME=$(basename "$CWD")

# --- 1. Create the git worktree ---

if [ -d "$WORKTREE_PATH" ]; then
  # Directory exists but may not be a valid worktree — clean it up
  rmdir "$WORKTREE_PATH" 2>/dev/null || true
fi

git -C "$CWD" worktree add "$WORKTREE_PATH" HEAD >&2

# Verify it worked
WT_GIT_DIR=$(git -C "$WORKTREE_PATH" rev-parse --git-dir 2>/dev/null || echo "")
WT_COMMON_DIR=$(git -C "$WORKTREE_PATH" rev-parse --git-common-dir 2>/dev/null || echo "")
if [ -z "$WT_GIT_DIR" ] || [ "$WT_GIT_DIR" = "$WT_COMMON_DIR" ]; then
  echo "ERROR: git worktree add succeeded but verification failed" >&2
  exit 1
fi

MESSAGES=()

# --- 2. Copy config files from main repo (don't overwrite existing) ---

if [ -f "$CWD/.env" ] && [ ! -f "$WORKTREE_PATH/.env" ]; then
  cp "$CWD/.env" "$WORKTREE_PATH/.env"
  MESSAGES+=("Copied .env")
fi

if [ -f "$CWD/.claude/settings.local.json" ]; then
  cp "$CWD/.claude/settings.local.json" "$WORKTREE_PATH/.claude/settings.local.json"
  MESSAGES+=("Copied .claude/settings.local.json")
fi

# --- 3. Install dependencies ---

# Poetry (Python) — create a proper Poetry-managed venv and install packages
if [ -f "$WORKTREE_PATH/poetry.lock" ] && command -v poetry &> /dev/null; then
  # Step 1: Create a Poetry-managed venv (in Poetry's cache dir, not in-project)
  PYTHON_PATH=$(pyenv which python 2>/dev/null || which python3 2>/dev/null || echo "")
  if [ -n "$PYTHON_PATH" ]; then
    echo "Creating Poetry venv for worktree..." >&2
    (cd "$WORKTREE_PATH" && poetry env use "$PYTHON_PATH" 2>&1 | tail -3) >&2 && \
      MESSAGES+=("Created Poetry venv") || \
      echo "WARNING: poetry env use failed" >&2
  fi

  # Step 2: Install packages into the venv
  echo "Installing Python dependencies (poetry install)..." >&2
  (cd "$WORKTREE_PATH" && poetry install 2>&1 | tail -5) >&2 && \
    MESSAGES+=("Installed Python deps (poetry)") || \
    echo "WARNING: poetry install failed — you may need to run it manually" >&2

  # Step 3: Run database migrations if manage.py exists
  WORK_VENV=$(cd "$WORKTREE_PATH" && poetry env info --path 2>/dev/null || echo "")
  if [ -f "$WORKTREE_PATH/manage.py" ] && [ -n "$WORK_VENV" ]; then
    echo "Running database migrations..." >&2
    (cd "$WORKTREE_PATH" && poetry run python manage.py migrate --no-input 2>&1 | tail -3) >&2 && \
      MESSAGES+=("Ran database migrations") || \
      echo "WARNING: migrations failed — you may need to run them manually" >&2
  fi
fi

# npm (Node.js)
if [ -f "$WORKTREE_PATH/package-lock.json" ] && command -v npm &> /dev/null; then
  echo "Installing Node.js dependencies (npm ci)..." >&2
  (cd "$WORKTREE_PATH" && npm ci --no-audit --no-fund 2>&1 | tail -3) >&2 && \
    MESSAGES+=("Installed Node deps (npm)") || \
    echo "WARNING: npm ci failed — you may need to run it manually" >&2
fi

# pip (requirements.txt fallback)
if [ ! -f "$WORKTREE_PATH/poetry.lock" ] && [ -f "$WORKTREE_PATH/requirements.txt" ] && command -v pip &> /dev/null; then
  echo "Installing Python dependencies (pip install)..." >&2
  (cd "$WORKTREE_PATH" && pip install -r requirements.txt 2>&1 | tail -3) >&2 && \
    MESSAGES+=("Installed Python deps (pip)") || \
    echo "WARNING: pip install failed — you may need to run it manually" >&2
fi

# --- 4. Register Claude Code plugins for worktree path ---

PLUGINS_JSON="$HOME/.claude/plugins/installed_plugins.json"
if [ -f "$PLUGINS_JSON" ] && command -v jq &> /dev/null; then
  ALREADY=$(jq --arg wtPath "$WORKTREE_PATH" '
    [.plugins[][]] | any(.projectPath == $wtPath)
  ' "$PLUGINS_JSON" 2>/dev/null || echo "false")

  if [ "$ALREADY" != "true" ]; then
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
    UPDATED=$(jq --arg mainPath "$CWD" --arg wtPath "$WORKTREE_PATH" --arg ts "$TIMESTAMP" '
      .plugins |= with_entries(
        .value |= (
          . as $entries |
          [.[] | select(.projectPath == $mainPath)] as $mainEntries |
          if ($mainEntries | length) == 0 then .
          elif any(.[]; .projectPath == $wtPath) then .
          else
            . + [$mainEntries[] | .projectPath = $wtPath | .installedAt = $ts | .lastUpdated = $ts]
          end
        )
      )
    ' "$PLUGINS_JSON")
    echo "$UPDATED" > "$PLUGINS_JSON"
    MESSAGES+=("Registered plugins for worktree path")
  fi
fi

# --- 5. Add to VS Code Project Manager ---

PROJECTS_JSON="$HOME/Library/Application Support/Code/User/globalStorage/alefragnani.project-manager/projects.json"
if [ -f "$PROJECTS_JSON" ] && command -v jq &> /dev/null; then
  ALREADY_PM=$(jq -e --arg path "$WORKTREE_PATH" 'any(.[]; .rootPath == $path)' "$PROJECTS_JSON" 2>/dev/null || echo "false")
  if [ "$ALREADY_PM" != "true" ]; then
    jq --arg name "${REPO_NAME}-${NAME}" \
       --arg path "$WORKTREE_PATH" \
       '. += [{"name": $name, "rootPath": $path, "paths": [], "tags": ["worktree"], "enabled": true, "profile": ""}]' \
       "$PROJECTS_JSON" > "$PROJECTS_JSON.tmp" && mv "$PROJECTS_JSON.tmp" "$PROJECTS_JSON"
    MESSAGES+=("Added to VSCode Project Manager")
  fi
fi

# --- 6. Open VSCode in the worktree ---

if command -v code &> /dev/null; then
  code "$WORKTREE_PATH" >&2 2>/dev/null &
  MESSAGES+=("Opened VSCode in worktree")
fi

# --- 7. Log summary to stderr (stdout is reserved for the path) ---

if [ ${#MESSAGES[@]} -gt 0 ]; then
  SUMMARY=$(printf '%s, ' "${MESSAGES[@]}")
  SUMMARY=${SUMMARY%, }
  echo "Worktree setup: ${SUMMARY}" >&2
fi

# --- 8. Print the worktree path (this is what Claude Code reads) ---

echo "$WORKTREE_PATH"
