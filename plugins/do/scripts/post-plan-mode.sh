#!/usr/bin/env bash
# PostToolUse hook for ExitPlanMode.
# Persists the plan from ~/.claude/plans/ to .claude/issues/{ISSUE}.plan.md
# and marks it as approved. Runs without LLM involvement so the user can
# safely accept the built-in context clear after Plan Mode exits.
set -euo pipefail

BRANCH=$(git branch --show-current 2>/dev/null || echo "")
ISSUE=""
if [[ "$BRANCH" =~ ^(feature|bugfix)/([0-9]+) ]]; then
  ISSUE="${BASH_REMATCH[2]}"
elif [[ "$BRANCH" =~ ^([0-9]+) ]]; then
  ISSUE="${BASH_REMATCH[1]}"
fi

if [ -z "$ISSUE" ]; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "message": "Could not detect issue number from branch. Persist the plan manually to .claude/issues/{ISSUE}.plan.md before clearing context."
  }
}
EOF
  exit 0
fi

# Find the plan file by issue number in the title heading
PLAN_FILE=$(grep -l "^# ${ISSUE}" ~/.claude/plans/*.md 2>/dev/null | head -1)

# Also try with # prefix (GitHub issue style)
if [ -z "$PLAN_FILE" ]; then
  PLAN_FILE=$(grep -l "^# #${ISSUE}" ~/.claude/plans/*.md 2>/dev/null | head -1)
fi

if [ -z "$PLAN_FILE" ]; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "message": "Could not find plan for #${ISSUE} in ~/.claude/plans/. Persist the plan manually to .claude/issues/${ISSUE}.plan.md before clearing context."
  }
}
EOF
  exit 0
fi

TARGET=".claude/issues/${ISSUE}.plan.md"
mkdir -p .claude/issues

# Copy and mark as approved
cp "$PLAN_FILE" "$TARGET"
sed -i '' 's/\[ \] Plan approved by user/[x] Plan approved by user/' "$TARGET"

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "message": "Plan persisted to ${TARGET} and marked as approved. You can safely clear context — the orchestrator will pick up at 'implementing' state on next /do:do."
  }
}
EOF
