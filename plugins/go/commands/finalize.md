# Finalize

Prepare branch for PR after review approval.

## Process

1. **Verify review approval**
   - Read `.claude/issues/{ISSUE_NUMBER}.review.md`
   - Confirm `✅ Approved`
   - Stop if not approved

2. **Run retro (before commit)**
   - `/go:retro` to capture learnings
   - Project-specific learnings → applied to `.claude/` files now
   - Universal learnings → queued for step 6

3. **Stage changes**
   ```bash
   git add -A
   ```
   This includes code changes AND any `.claude/` file updates from retro.

4. **Commit**
   ```bash
   git commit -m "{ISSUE_NUMBER}: concise description"
   ```

5. **Push**
   ```bash
   git push -u origin feature/{ISSUE_NUMBER}_description
   ```

6. **Apply universal learnings to plugin**
   If retro identified universal learnings:
   ```bash
   git -C ~/.claude/plugins/marketplaces/ezeYaniv pull
   # Apply queued updates to command files
   git -C ~/.claude/plugins/marketplaces/ezeYaniv add -A
   git -C ~/.claude/plugins/marketplaces/ezeYaniv commit -m "retro({ISSUE_NUMBER}): {brief description}"
   git -C ~/.claude/plugins/marketplaces/ezeYaniv push
   ```

7. **Create PR via GitHub CLI**

   ```bash
   gh pr create --base uat --title "{ISSUE_NUMBER}: {description}" --body "$(cat <<'EOF'
   ## Summary
   - {bullet 1}
   - {bullet 2}

   ## Testing
   - [x] Unit tests pass
   - [x] E2E tests pass (if applicable)
   - [ ] Manual verification

   Closes {ISSUE_NUMBER}
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

## Commit Message Style

- Prefix with ticket: `{ISSUE_NUMBER}: description`
- Brief and descriptive (50 chars or less)
- Focus on what, not how
