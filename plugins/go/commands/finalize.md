# Finalize

Prepare branch for PR after review approval.

## Process

1. **Verify review approval**
   - Read `.claude/issues/{ISSUE_NUMBER}.review.md`
   - Confirm `Approved`
   - Stop if not approved

2. **Reconcile plan with actual changes**

   The plan may have drifted during iteration — especially when the user gave feedback that eng implemented without updating the plan. Before committing, make the plan match reality.

   - Run `git diff main...HEAD` to see all code changes
   - Read `.claude/issues/{ISSUE_NUMBER}.plan.md`
   - Compare: are there implemented features, modified signatures, added/removed behaviors, or changed approaches not reflected in the plan?
   - Update the plan's Specification and Implementation sections to accurately describe what was actually built
   - Keep the plan's format and structure intact — just make it truthful
   - If changes are minor (naming, implementation details), update inline
   - If changes are significant (new endpoints, changed behavior), add/revise the relevant spec sections

   The goal: someone reading the committed plan can understand exactly what was built and why.

3. **Run retro (before commit)**
   - `/go:retro` to capture learnings
   - Project-specific learnings -> applied to `.claude/` files now
   - Universal learnings -> queued for step 7

4. **Stage changes**
   ```bash
   git add -A
   ```
   This includes code changes, reconciled plan, AND any `.claude/` file updates from retro.

5. **Commit**
   ```bash
   git commit -m "{ISSUE_NUMBER}: concise description"
   ```

6. **Push**
   ```bash
   git push -u origin feature/{ISSUE_NUMBER}_description
   ```

7. **Apply universal learnings to plugin**
   If retro identified universal learnings:
   ```bash
   git -C ~/.claude/plugins/marketplaces/ezeYaniv pull
   # Apply queued updates to command files
   # IMPORTANT: Bump version in .claude-plugin/plugin.json — Claude Code
   # uses this to decide whether to update the cache. Without a bump,
   # users won't see changes.
   git -C ~/.claude/plugins/marketplaces/ezeYaniv add -A
   git -C ~/.claude/plugins/marketplaces/ezeYaniv commit -m "retro({ISSUE_NUMBER}): {brief description}"
   git -C ~/.claude/plugins/marketplaces/ezeYaniv push
   ```

7. **Create PR via GitHub CLI**

**IMPORTANT:** The default target branch should be main.

   ```bash
   gh pr create --base main --title "{ISSUE_NUMBER}: {description}" --body "$(cat <<'EOF'
   ## Summary
   - {bullet 1}
   - {bullet 2}

   ## Testing
   - [x] Unit tests pass
   - [x] E2E tests pass (if applicable)
   - [ ] Manual verification

   Closes #{ISSUE_NUMBER}
   EOF
   )"
   ```

   Output the PR URL returned by `gh pr create`.

   ```
   PR created: {pr-url}

   Learnings applied:
   - Project: [list .claude/ files updated, if any]
   - Plugin: [list plugin updates, if any]
   ```

8. **Worktree cleanup (if applicable)**

   Check if we're in a worktree:
   ```bash
   IS_WORKTREE=$([ "$(git rev-parse --git-common-dir)" != "$(git rev-parse --git-dir)" ] && echo "true" || echo "false")
   ```

   If in a worktree:
   - Get main repo path:
     ```bash
     MAIN_REPO=$(dirname "$(git rev-parse --git-common-dir)")
     WORKTREE_PATH=$(git rev-parse --show-toplevel)
     ```

   - **Intelligent settings sync with conflict resolution:**

     For each config file, compare worktree vs main and handle intelligently:

     **Step 1: Analyze differences**

     For `.env` (key=value format):
     - Parse both files into key=value pairs
     - Categorize: unchanged, added in worktree, removed in worktree, conflicts

     For `.claude/settings.local.json` (JSON):
     - Deep compare using jq
     - Identify added keys, removed keys, and conflicting values

     **Step 2: Create backups**

     Before any changes, backup main repo files:
     ```bash
     TIMESTAMP=$(date +%Y%m%d_%H%M%S)
     [ -f "${MAIN_REPO}/.env" ] && cp "${MAIN_REPO}/.env" "${MAIN_REPO}/.env.backup.${TIMESTAMP}"
     [ -f "${MAIN_REPO}/.claude/settings.local.json" ] && cp "${MAIN_REPO}/.claude/settings.local.json" "${MAIN_REPO}/.claude/settings.local.json.backup.${TIMESTAMP}"
     ```

     **Step 3: Display diff and resolve conflicts**

     Show user what will change:
     ```
     Settings sync from worktree to main repo:

     .env:
       Unchanged: 12 keys
       Will add: NEW_VAR=value, ANOTHER_VAR=123
       Conflicts:

       [1] DATABASE_URL
           Main:     postgres://localhost:5432/main_db
           Worktree: postgres://localhost:5432/feature_db
           Keep: (m)ain / (w)orktree / (s)kip?

     .claude/settings.local.json:
       No conflicts
       Will add: newPermission key
     ```

     For each conflict, prompt user to choose:
     - **(m)ain** - Keep the main repo's value
     - **(w)orktree** - Use the worktree's value
     - **(s)kip** - Don't sync this key at all

     **Step 4: Apply merged result**

     After all conflicts resolved, write the merged config to main repo.

     **Step 5: Summary**
     ```
     Settings sync complete:
     - .env: 2 added, 1 conflict (kept worktree), backup at .env.backup.20250123_143022
     - settings.local.json: 1 added, no conflicts
     ```

   - Ask user: "Remove this worktree? (y/n)"
   - If yes:

     **Remove from VS Code Project Manager BEFORE deleting worktree** (the worktree path must still exist to resolve it):
     ```bash
     PROJECTS_JSON="$HOME/Library/Application Support/Code/User/globalStorage/alefragnani.project-manager/projects.json"
     if [ -f "$PROJECTS_JSON" ] && command -v jq &> /dev/null; then
       ABSOLUTE_PATH="$(cd "${WORKTREE_PATH}" && pwd)"
       jq --arg path "$ABSOLUTE_PATH" 'map(select(.rootPath != $path))' \
          "$PROJECTS_JSON" > "$PROJECTS_JSON.tmp" && mv "$PROJECTS_JSON.tmp" "$PROJECTS_JSON"
       echo "Removed from VS Code Project Manager"
     fi
     ```

     **Then remove the worktree:**
     ```bash
     cd "${MAIN_REPO}"
     git worktree remove "${WORKTREE_PATH}" --force
     ```
   - Output:
     ```
     Worktree removed. Settings synced to main repo.
     Switch back to main repo terminal to continue.
     ```

## Commit Message Style

- Prefix with issue number: `{ISSUE_NUMBER}: description`
- Brief and descriptive (50 chars or less)
- Focus on what, not how
