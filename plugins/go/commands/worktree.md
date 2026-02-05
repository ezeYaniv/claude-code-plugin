# Worktree Management

Manage git worktrees for parallel development. Allows working on multiple issues simultaneously in isolated directories.

## Subcommands

Parse `$ARGUMENTS` to determine which subcommand to run:
- `setup {ISSUE_NUMBER}` - Create worktree for issue
- `list` - Show all worktrees
- `cleanup {ISSUE_NUMBER}` - Remove worktree and sync settings back
- `sync` - Sync settings from main repo to current worktree

If no subcommand provided, show help.

---

## Setup

`/go:worktree setup {ISSUE_NUMBER}`

Create a new worktree for the given issue.

### Process

1. **Validate environment**
   ```bash
   # Get repo name and main repo path
   REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
   MAIN_REPO=$(git rev-parse --show-toplevel)
   WORKTREE_PATH="../${REPO_NAME}-${ISSUE_NUMBER}"
   ```

2. **Check if already in a worktree**
   ```bash
   # If git rev-parse --git-common-dir differs from --git-dir, we're in a worktree
   if [ "$(git rev-parse --git-common-dir)" != "$(git rev-parse --git-dir)" ]; then
     echo "Already in a worktree. Run this from the main repo."
     exit 1
   fi
   ```

3. **Check if worktree already exists**
   ```bash
   if git worktree list | grep -q "${ISSUE_NUMBER}"; then
     EXISTING_PATH=$(git worktree list | grep "${ISSUE_NUMBER}" | awk '{print $1}')
     echo "Worktree for ${ISSUE_NUMBER} already exists at ${EXISTING_PATH}"
     exit 0
   fi
   ```

4. **Fetch latest and create branch**
   ```bash
   git fetch origin
   # Get issue title from GitHub for branch name
   TITLE=$(gh issue view ${ISSUE_NUMBER} --json title -q '.title')
   # Slugify: lowercase, replace spaces with hyphens, remove special chars
   BRANCH_NAME="feature/${ISSUE_NUMBER}_${SLUGIFIED_TITLE}"
   ```

5. **Create worktree**
   ```bash
   git worktree add "${WORKTREE_PATH}" -b "${BRANCH_NAME}" origin/main
   ```

6. **Copy settings files**
   ```bash
   # Copy .env if exists
   [ -f ".env" ] && cp ".env" "${WORKTREE_PATH}/.env"

   # Copy .claude/settings.local.json if exists
   [ -f ".claude/settings.local.json" ] && cp ".claude/settings.local.json" "${WORKTREE_PATH}/.claude/settings.local.json"
   ```

7. **Install dependencies and set up hooks**
   ```bash
   cd "${WORKTREE_PATH}"
   npm install  # Installs dependencies and triggers Husky's prepare script for git hooks
   if [ -f "pyproject.toml" ]; then
      poetry install
   fi
   echo "Dependencies installed and git hooks configured"
   ```

8. **VS Code integration**
   ```bash
   # Open worktree in new VS Code window if 'code' command is available
   if command -v code &> /dev/null; then
     code -n "$(cd "${WORKTREE_PATH}" && pwd)"
     echo "Opened VS Code in new window for ${ISSUE_NUMBER}"
   fi
   ```

9. **Add to VS Code Project Manager**
   ```bash
   # Add worktree to Project Manager for fast switching
   PROJECTS_JSON="$HOME/Library/Application Support/Code/User/globalStorage/alefragnani.project-manager/projects.json"
   if [ -f "$PROJECTS_JSON" ] && command -v jq &> /dev/null; then
     ABSOLUTE_PATH="$(cd "${WORKTREE_PATH}" && pwd)"
     jq --arg name "${REPO_NAME}-${ISSUE_NUMBER}" \
        --arg path "$ABSOLUTE_PATH" \
        '. += [{"name": $name, "rootPath": $path, "paths": [], "tags": ["worktree"], "enabled": true, "profile": ""}]' \
        "$PROJECTS_JSON" > "$PROJECTS_JSON.tmp" && mv "$PROJECTS_JSON.tmp" "$PROJECTS_JSON"
     echo "Added to VS Code Project Manager"
   fi
   ```

10. **Output summary**
   ```
   Worktree created:
   - Path: {absolute_path}
   - Branch: {branch_name}
   - Settings copied: .env, .claude/settings.local.json

   Next: Open a terminal in the worktree directory and run 'claude'
   ```

---

## List

`/go:worktree list`

Show all worktrees and their status.

### Process

1. **Get worktree list**
   ```bash
   git worktree list
   ```

2. **For each worktree, show:**
   - Path
   - Branch name
   - Issue (extracted from branch)
   - Status (clean/dirty)

3. **Output format**
   ```
   Worktrees:

   1. /path/to/repo-123
      Branch: feature/123_add-feature
      Status: 2 files modified

   2. /path/to/repo-456
      Branch: feature/456_fix-bug
      Status: clean

   Main: /path/to/repo (main)
   ```

---

## Cleanup

`/go:worktree cleanup {ISSUE_NUMBER}`

Remove a worktree and sync settings back to main repo.

### Process

1. **Find worktree path**
   ```bash
   WORKTREE_PATH=$(git worktree list | grep "${ISSUE_NUMBER}" | awk '{print $1}')
   if [ -z "$WORKTREE_PATH" ]; then
     echo "No worktree found for ${ISSUE_NUMBER}"
     exit 1
   fi
   ```

2. **Get main repo path**
   ```bash
   MAIN_REPO=$(git rev-parse --git-common-dir | sed 's/\.git$//')
   # Handle case where we're in the worktree vs main repo
   if [ "$(git rev-parse --git-common-dir)" != "$(git rev-parse --git-dir)" ]; then
     # We're in a worktree, get main repo from common dir
     MAIN_REPO=$(dirname "$(git rev-parse --git-common-dir)")
   else
     MAIN_REPO=$(git rev-parse --show-toplevel)
   fi
   ```

3. **Intelligent settings sync with conflict resolution**

   For each config file (`.env`, `.claude/settings.local.json`), perform intelligent merge instead of blind copy.

   **For .env files**:

   ```bash
   sync_env_file() {
     local WORKTREE_FILE="$1"
     local MAIN_FILE="$2"
     local FILE_NAME="$3"

     # Skip if worktree file doesn't exist
     [ ! -f "$WORKTREE_FILE" ] && return 0

     # If main file doesn't exist, just copy
     if [ ! -f "$MAIN_FILE" ]; then
       cp "$WORKTREE_FILE" "$MAIN_FILE"
       echo "  ${FILE_NAME}: Copied (new file)"
       return 0
     fi

     # Create backup with timestamp
     BACKUP="${MAIN_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
     cp "$MAIN_FILE" "$BACKUP"

     # Parse both files into associative arrays (key=value)
     declare -A MAIN_VARS WORKTREE_VARS
     while IFS='=' read -r key value; do
       [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
       MAIN_VARS["$key"]="$value"
     done < "$MAIN_FILE"

     while IFS='=' read -r key value; do
       [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
       WORKTREE_VARS["$key"]="$value"
     done < "$WORKTREE_FILE"

     # Categorize changes
     local ADDED=() CONFLICTS=() UNCHANGED=0

     for key in "${!WORKTREE_VARS[@]}"; do
       if [ -z "${MAIN_VARS[$key]+x}" ]; then
         ADDED+=("$key")
       elif [ "${MAIN_VARS[$key]}" != "${WORKTREE_VARS[$key]}" ]; then
         CONFLICTS+=("$key")
       else
         ((UNCHANGED++))
       fi
     done
   }
   ```

   **Display diff and prompt for conflicts:**

   ```
   Settings sync for .env:

   ✅ Unchanged: 12 keys
   ➕ New in worktree (will add to main):
      + NEW_API_KEY=abc123
      + FEATURE_FLAG=true

   ⚠️  Conflicts (same key, different values):

   [1] DATABASE_URL
       Main:     postgres://localhost:5432/main_db
       Worktree: postgres://localhost:5432/feature_db

       Keep: (m)ain / (w)orktree / (s)kip?

   [2] DEBUG_MODE
       Main:     false
       Worktree: true

       Keep: (m)ain / (w)orktree / (s)kip?
   ```

   For each conflict, wait for user input and apply their choice.

   **For JSON files** (`.claude/settings.local.json`):

   Use `jq` to deep-diff and merge:

   ```bash
   sync_json_file() {
     local WORKTREE_FILE="$1"
     local MAIN_FILE="$2"

     [ ! -f "$WORKTREE_FILE" ] && return 0

     if [ ! -f "$MAIN_FILE" ]; then
       cp "$WORKTREE_FILE" "$MAIN_FILE"
       echo "  settings.local.json: Copied (new file)"
       return 0
     fi

     # Create backup
     BACKUP="${MAIN_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
     cp "$MAIN_FILE" "$BACKUP"

     # Get diff using jq
     # Keys only in worktree, only in main, and conflicts
     WORKTREE_ONLY=$(jq -r 'keys[]' "$WORKTREE_FILE" | while read k; do
       jq -e ".[\"$k\"]" "$MAIN_FILE" > /dev/null 2>&1 || echo "$k"
     done)

     CONFLICTS=$(jq -r 'keys[]' "$WORKTREE_FILE" | while read k; do
       MAIN_VAL=$(jq -c ".[\"$k\"]" "$MAIN_FILE" 2>/dev/null)
       WORKTREE_VAL=$(jq -c ".[\"$k\"]" "$WORKTREE_FILE")
       if [ -n "$MAIN_VAL" ] && [ "$MAIN_VAL" != "$WORKTREE_VAL" ]; then
         echo "$k"
       fi
     done)
   }
   ```

   **Display JSON diff and prompt:**

   ```
   Settings sync for .claude/settings.local.json:

   ➕ New keys in worktree (will add):
      + newPermission: {...}

   ⚠️  Conflicts:

   [1] permissions.allowedTools
       Main:     ["Read", "Write", "Bash"]
       Worktree: ["Read", "Write", "Bash", "Edit"]

       Keep: (m)ain / (w)orktree / (s)kip?
   ```

   **After all resolutions:**

   ```
   Settings sync complete:
   - .env: 2 added, 1 conflict resolved (kept worktree), backup at .env.backup.20250123_143022
   - settings.local.json: 1 added, 0 conflicts, backup at settings.local.json.backup.20250123_143022
   ```

4. **Check for uncommitted changes**
   ```bash
   cd "${WORKTREE_PATH}"
   if [ -n "$(git status --porcelain)" ]; then
     echo "Warning: Worktree has uncommitted changes!"
     git status --short
     echo "Proceed with cleanup anyway? (y/n)"
     # Wait for user confirmation
   fi
   ```

5. **Remove from VS Code Project Manager**
   ```bash
   # Remove worktree from Project Manager
   PROJECTS_JSON="$HOME/Library/Application Support/Code/User/globalStorage/alefragnani.project-manager/projects.json"
   if [ -f "$PROJECTS_JSON" ] && command -v jq &> /dev/null; then
     ABSOLUTE_PATH="$(cd "${WORKTREE_PATH}" && pwd)"
     jq --arg path "$ABSOLUTE_PATH" 'map(select(.rootPath != $path))' \
        "$PROJECTS_JSON" > "$PROJECTS_JSON.tmp" && mv "$PROJECTS_JSON.tmp" "$PROJECTS_JSON"
     echo "Removed from VS Code Project Manager"
   fi
   ```

6. **Remove worktree**
   ```bash
   git worktree remove "${WORKTREE_PATH}" --force
   ```

7. **Output summary**
   ```
   Worktree removed: {path}
   Settings synced back to: {main_repo}
   ```

---

## Sync

`/go:worktree sync`

Manually sync settings from main repo to current worktree. Useful if settings were updated in main repo after worktree was created (e.g., another worktree finished and synced new settings).

### Process

1. **Validate we're in a worktree**
   ```bash
   if [ "$(git rev-parse --git-common-dir)" = "$(git rev-parse --git-dir)" ]; then
     echo "Not in a worktree. Run this from a worktree directory."
     exit 1
   fi
   ```

2. **Get paths**
   ```bash
   MAIN_REPO=$(dirname "$(git rev-parse --git-common-dir)")
   WORKTREE_PATH=$(git rev-parse --show-toplevel)
   ```

3. **Intelligent sync with conflict resolution (main → worktree)**

   For each config file, compare main vs worktree:

   **Step 1: Create backups of worktree files**
   ```bash
   TIMESTAMP=$(date +%Y%m%d_%H%M%S)
   [ -f "${WORKTREE_PATH}/.env" ] && cp "${WORKTREE_PATH}/.env" "${WORKTREE_PATH}/.env.backup.${TIMESTAMP}"
   [ -f "${WORKTREE_PATH}/.claude/settings.local.json" ] && cp "${WORKTREE_PATH}/.claude/settings.local.json" "${WORKTREE_PATH}/.claude/settings.local.json.backup.${TIMESTAMP}"
   ```

   **Step 2: Analyze differences**

   For `.env` files:
   - Keys only in main (new) → will add to worktree
   - Keys only in worktree → keep (local changes)
   - Same value → no action
   - Different value → CONFLICT

   **Step 3: Display diff and resolve conflicts**

   ```
   Settings sync from main repo to worktree:

   .env:
     ✅ Unchanged: 10 keys
     ➕ New in main (will add): NEW_SHARED_VAR=value
     🔒 Only in worktree (will keep): LOCAL_DEBUG=true
     ⚠️  Conflicts:

     [1] API_ENDPOINT
         Main:     https://api.prod.example.com
         Worktree: https://api.staging.example.com
         Keep: (m)ain / (w)orktree / (s)kip?
   ```

   For each conflict, prompt:
   - **(m)ain** - Take the main repo's value
   - **(w)orktree** - Keep the worktree's value
   - **(s)kip** - Leave unchanged

   **Step 4: Apply merged result**

   Write merged config to worktree.

4. **Output summary**
   ```
   Settings synced from main repo:
   - .env: 1 added from main, 1 conflict (kept worktree)
   - settings.local.json: no changes

   Backups saved with timestamp {TIMESTAMP}
   ```

---

## Help

If no subcommand or unrecognized subcommand:

```
Worktree Management - Work on multiple issues in parallel

Usage:
  /go:worktree setup {ISSUE_NUMBER}   Create worktree for issue
  /go:worktree list                   Show all worktrees
  /go:worktree cleanup {ISSUE_NUMBER} Remove worktree, sync settings back
  /go:worktree sync                   Sync settings from main repo

Example:
  /go:worktree setup 123              # Creates ../repo-123 worktree
  /go:worktree list                   # Shows all active worktrees
  /go:worktree cleanup 123            # Removes worktree after PR merged
```
