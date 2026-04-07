#!/usr/bin/env bash
# Deterministic status detection for the go plugin.
# Outputs formatted status report with no LLM involvement.
set -euo pipefail

# --- Detect worktree vs main repo ---
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)

if [ "$GIT_DIR" != "$GIT_COMMON_DIR" ]; then
  IS_WORKTREE=true
  MAIN_REPO=$(dirname "$GIT_COMMON_DIR")
else
  IS_WORKTREE=false
  MAIN_REPO="$TOPLEVEL"
fi

# --- Branch and issue ---
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")

# Extract issue number from branch: feature/123_desc, bugfix/123_desc, or 123-desc
ISSUE=""
if [[ "$BRANCH" =~ ^(feature|bugfix)/([0-9]+) ]]; then
  ISSUE="${BASH_REMATCH[2]}"
elif [[ "$BRANCH" =~ ^([0-9]+) ]]; then
  ISSUE="${BASH_REMATCH[1]}"
fi

# --- Plan file ---
PLAN_FILE=""
PLAN_EXISTS=false
PLAN_DRAFTED=false
PLAN_APPROVED=false
IMPL_COMPLETE=false
REVIEW_APPROVED=false
TASKS_DONE=0
TASKS_TOTAL=0

if [ -n "$ISSUE" ]; then
  PLAN_FILE=".claude/issues/${ISSUE}.plan.md"
  if [ -f "$PLAN_FILE" ]; then
    PLAN_EXISTS=true

    # Parse status checkboxes
    grep -q '\[x\] Plan drafted' "$PLAN_FILE" 2>/dev/null && PLAN_DRAFTED=true
    grep -q '\[x\] Plan approved by user' "$PLAN_FILE" 2>/dev/null && PLAN_APPROVED=true
    grep -q '\[x\] Implementation complete' "$PLAN_FILE" 2>/dev/null && IMPL_COMPLETE=true
    grep -q '\[x\] Code review approved' "$PLAN_FILE" 2>/dev/null && REVIEW_APPROVED=true

    # Count tasks (lines starting with - [ ] or - [x] under ## Tasks)
    IN_TASKS=false
    while IFS= read -r line; do
      if [[ "$line" =~ ^##\ Tasks ]]; then
        IN_TASKS=true
        continue
      fi
      if $IN_TASKS && [[ "$line" =~ ^## ]] && [[ ! "$line" =~ ^###  ]]; then
        # Hit a new h2 section, stop counting
        break
      fi
      if $IN_TASKS; then
        if [[ "$line" =~ ^[[:space:]]*-\ \[x\] ]]; then
          ((TASKS_DONE++)) || true
          ((TASKS_TOTAL++)) || true
        elif [[ "$line" =~ ^[[:space:]]*-\ \[\ \] ]]; then
          ((TASKS_TOTAL++)) || true
        fi
      fi
    done < "$PLAN_FILE"
  fi
fi

# --- Review file ---
REVIEW_FILE=""
REVIEW_EXISTS=false
REVIEW_VERDICT=""

if [ -n "$ISSUE" ]; then
  REVIEW_FILE=".claude/issues/${ISSUE}.review.md"
  if [ -f "$REVIEW_FILE" ]; then
    REVIEW_EXISTS=true
    REVIEW_VERDICT=$(grep '\*\*Verdict:\*\*' "$REVIEW_FILE" 2>/dev/null | head -1 | sed 's/.*\*\*Verdict:\*\*[[:space:]]*//' || echo "")
  fi
fi

# --- Git status ---
GIT_STATUS=$(git status --short 2>/dev/null)
if [ -z "$GIT_STATUS" ]; then
  GIT_FILES_MODIFIED=0
else
  GIT_FILES_MODIFIED=$(echo "$GIT_STATUS" | wc -l | tr -d ' ')
fi
GIT_AHEAD=""
# Try to get ahead/behind info
if git rev-parse --verify origin/main &>/dev/null; then
  AHEAD=$(git log origin/main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
  BEHIND=$(git log HEAD..origin/main --oneline 2>/dev/null | wc -l | tr -d ' ')
  if [ "$AHEAD" -gt 0 ] && [ "$BEHIND" -gt 0 ]; then
    GIT_AHEAD="ahead $AHEAD, behind $BEHIND vs origin/main"
  elif [ "$AHEAD" -gt 0 ]; then
    GIT_AHEAD="ahead $AHEAD vs origin/main"
  elif [ "$BEHIND" -gt 0 ]; then
    GIT_AHEAD="behind $BEHIND vs origin/main"
  else
    GIT_AHEAD="up to date with origin/main"
  fi
fi

# --- GitHub issue status (via gh if available) ---
GH_STATUS=""
if [ -n "$ISSUE" ] && command -v gh &>/dev/null; then
  GH_STATUS=$(gh issue view "$ISSUE" --json title,state -q '"#\(.number // ""): \(.title // "")\nStatus: \(.state // "")"' 2>/dev/null || echo "")
fi

# --- Compute state ---
STATE="no-issue"
NEXT=""

if [ -z "$ISSUE" ]; then
  STATE="no-issue"
  NEXT="Run /go:go {ISSUE_NUMBER} to start a new issue"
elif ! $PLAN_EXISTS; then
  STATE="needs-plan"
  NEXT="Run /go:plan to create implementation plan"
elif $PLAN_DRAFTED && ! $PLAN_APPROVED; then
  STATE="needs-approval"
  NEXT="Review and approve the plan"
elif $PLAN_APPROVED && ! $IMPL_COMPLETE; then
  STATE="implementing"
  NEXT="Continue implementation (run /go:eng)"
elif $IMPL_COMPLETE && ! $REVIEW_EXISTS; then
  STATE="reviewing"
  NEXT="Run /go:rev to review implementation"
elif $REVIEW_EXISTS && [[ "$REVIEW_VERDICT" == *"Iterate"* ]]; then
  STATE="iterating"
  NEXT="Fix review issues (run /go:eng), then re-review"
elif $REVIEW_EXISTS && [[ "$REVIEW_VERDICT" == *"Revise Plan"* ]]; then
  STATE="needs-revision"
  NEXT="Revise plan based on review feedback"
elif $REVIEW_APPROVED; then
  STATE="approved"
  NEXT="Run /go:finalize to create PR"
elif $REVIEW_EXISTS && [[ "$REVIEW_VERDICT" == *"Approved"* ]]; then
  STATE="approved"
  NEXT="Run /go:finalize to create PR"
fi

# Check if already pushed/committed (finalized)
if [ -n "$ISSUE" ] && git log --oneline -1 2>/dev/null | grep -q "${ISSUE}:" 2>/dev/null; then
  if [ "$GIT_FILES_MODIFIED" -eq 0 ]; then
    STATE="finalized"
    NEXT="Done - suggest /go:retro"
  fi
fi

# --- Output ---
echo ""

if $IS_WORKTREE; then
  echo "Worktree: $TOPLEVEL (main repo: $MAIN_REPO)"
else
  echo "Repo:     $TOPLEVEL (main)"
fi

echo "Branch:   $BRANCH"

if [ -n "$ISSUE" ]; then
  if [ -n "$GH_STATUS" ]; then
    echo "Issue:    #$ISSUE"
    echo "$GH_STATUS" | while IFS= read -r line; do
      echo "          $line"
    done
  else
    echo "Issue:    #$ISSUE"
  fi
fi

echo ""

if $PLAN_EXISTS; then
  echo "Plan:     $PLAN_FILE"
  $PLAN_DRAFTED && echo "          [x] Plan drafted" || echo "          [ ] Plan drafted"
  $PLAN_APPROVED && echo "          [x] Plan approved by user" || echo "          [ ] Plan approved by user"
  $IMPL_COMPLETE && echo "          [x] Implementation complete" || echo "          [ ] Implementation complete"
  $REVIEW_APPROVED && echo "          [x] Code review approved" || echo "          [ ] Code review approved"
  if [ "$TASKS_TOTAL" -gt 0 ]; then
    echo "          Tasks: ${TASKS_DONE}/${TASKS_TOTAL} complete"
  fi
elif [ -n "$ISSUE" ]; then
  echo "Plan:     Not yet created"
fi

echo ""

if $REVIEW_EXISTS; then
  echo "Review:   $REVIEW_FILE"
  [ -n "$REVIEW_VERDICT" ] && echo "          $REVIEW_VERDICT"
elif [ -n "$ISSUE" ]; then
  echo "Review:   Not yet created"
fi

echo ""

if [ "$GIT_FILES_MODIFIED" -gt 0 ]; then
  echo "Git:      $GIT_FILES_MODIFIED files modified, not committed"
else
  echo "Git:      Clean working directory"
fi
[ -n "$GIT_AHEAD" ] && echo "          $GIT_AHEAD"

# List worktrees if in main repo
if ! $IS_WORKTREE; then
  WORKTREES=$(git worktree list 2>/dev/null | tail -n +2)
  if [ -n "$WORKTREES" ]; then
    echo ""
    echo "Active Worktrees:"
    while IFS= read -r wt; do
      WT_PATH=$(echo "$wt" | awk '{print $1}')
      WT_BRANCH=$(echo "$wt" | sed -n 's/.*\[\(.*\)\].*/\1/p')
      WT_STATUS=$(git -C "$WT_PATH" status --short 2>/dev/null | wc -l | tr -d ' ')
      if [ "$WT_STATUS" -gt 0 ]; then
        echo "  - $WT_PATH -> $WT_BRANCH ($WT_STATUS files modified)"
      else
        echo "  - $WT_PATH -> $WT_BRANCH (clean)"
      fi
    done <<< "$WORKTREES"
  fi
fi

echo ""
echo "State:    $STATE"
echo "Next:     $NEXT"
echo ""
