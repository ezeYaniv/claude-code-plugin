# Workflow Overview

## State Machine

```
                    ┌─────────────────┐
                    │    no-issue     │
                    └────────┬────────┘
                             │ /go:go {ISSUE_NUMBER}
                             ▼
                    ┌─────────────────┐
                    │   needs-plan    │
                    └────────┬────────┘
                             │ /go:plan
                             ▼
                    ┌─────────────────┐
              ┌────▶│ needs-approval  │◀────┐
              │     └────────┬────────┘     │
              │              │ user approves│
              │              ▼              │
              │     ┌─────────────────┐     │
              │     │  implementing   │     │
              │     └────────┬────────┘     │
              │              │ /go:eng      │
              │              ▼              │
              │     ┌─────────────────┐     │
              │     │   reviewing     │     │
              │     └────────┬────────┘     │
              │              │ /go:rev      │
              │              ▼              │
              │     ┌─────────────────┐     │
   plan needs │     │   iterating     │─────┘
   revision   │     └────────┬────────┘ fixable issues
              │              │ (auto loop)
              │              ▼
              │     ┌─────────────────┐
              └─────│ needs-revision  │
                    └─────────────────┘
                             │
            (when approved)  │
                             ▼
                    ┌─────────────────┐
                    │    approved     │
                    └────────┬────────┘
                             │ /go:finalize
                             ▼
                    ┌─────────────────┐
                    │   finalized     │
                    └─────────────────┘
```

## Human Breakpoints

The workflow stops and waits for human input at these points:

1. **needs-approval** - Plan is ready, user must review and approve
2. **needs-revision** - Reviewer found issues requiring plan changes

Everything else is automatic - the eng ↔ rev loop iterates without user involvement.

## The Iteration Loop

When reviewer finds fixable issues:

```
/go:eng reads review, fixes issues
    ↓
/go:eng marks implementation complete
    ↓
/go:rev re-reviews
    ↓
(repeat until approved or needs-revision)
```

**User is NOT involved in this loop.** Only plan-level issues stop the loop.

## Learning Loop

Two mechanisms for improving the workflow:

### Immediate Learning (`/go:learn`)

When user corrects behavior mid-session:
1. Apply correction immediately
2. Identify pattern
3. Suggest permanent update to plugin
4. If approved, commit and push

### Post-Issue Learning (`/go:retro`)

After completing work:
1. Review plan and review files
2. Identify patterns from iterations
3. Propose updates to plugin
4. If approved, commit and push

## Typical Session

```
User: /go:go 123

Claude: [runs /plugin update go]
        [runs /go:status]
        State: needs-plan
        Running /go:plan...

Claude: [researches codebase]
        [writes plan to .claude/issues/123.plan.md]
        Plan ready for review. [STOPS]

User: Looks good, approved.

Claude: [marks plan approved]
        Running /go:eng...
        [implements using TDD]
        Implementation complete.
        Running /go:rev...
        [reviews changes]
        🔄 Iterate - found 2 issues
        Running /go:eng...
        [fixes issues]
        Running /go:rev...
        ✅ Approved
        Ready for /go:finalize

User: Finalize it.

Claude: [runs /go:retro]
        No learnings identified.
        [commits and pushes]
        Branch pushed. Ready for PR.
```
