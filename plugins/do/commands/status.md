---
name: status
description: Show current project state. Used by both user (visibility) and orchestrator (routing).
---

!`${CLAUDE_PLUGIN_ROOT}/scripts/status.sh`

Display the status report above to the user. Do not re-run any of the commands — the output above is current.

If the user asks for more detail on a specific section (e.g., GitHub issue details, full git log), you can run additional commands to expand on that section only.
