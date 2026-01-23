#!/usr/bin/env python3
"""Status line script for Claude Code CLI."""

import json
import re
import subprocess
import sys
from pathlib import Path

PROMPT_HISTORY_FILE = Path("/tmp/claude_prompt_history.json")
MAX_PROMPT_DISPLAY_LEN = 50

# ANSI color codes
DARK_BLUE = "\033[34m"
DARK_GREEN = "\033[32m"
DARK_GRAY = "\033[90m"
MEDIUM_GRAY = "\033[37m"
CYAN = "\033[36m"
YELLOW = "\033[33m"
BLACK = "\033[30m"
RESET = "\033[0m"


def get_prompt_history() -> list[str]:
    """Read recent prompts from temp file."""
    if not PROMPT_HISTORY_FILE.exists():
        return []
    try:
        data = json.loads(PROMPT_HISTORY_FILE.read_text())
        return data.get("prompts", [])[-3:]
    except (json.JSONDecodeError, OSError):
        return []


def truncate(text: str, max_len: int) -> str:
    """Truncate text with ellipsis if too long."""
    text = text.replace("\n", " ").strip()
    if len(text) <= max_len:
        return text
    return text[: max_len - 1] + "…"


def extract_issue_id(branch: str) -> str | None:
    """Extract issue number from branch name (e.g., feature/123_desc -> #123)."""
    match = re.search(r"(?:feature|bugfix|fix)/(\d+)", branch, re.IGNORECASE)
    return f"#{match.group(1)}" if match else None


def format_context_usage(context_window: dict) -> str:
    """Format context window usage as percentage."""
    current_usage = context_window.get("current_usage", {})
    context_size = context_window.get("context_window_size", 200000)

    input_tokens = current_usage.get("input_tokens", 0)
    cache_creation = current_usage.get("cache_creation_input_tokens", 0)
    cache_read = current_usage.get("cache_read_input_tokens", 0)
    current_tokens = input_tokens + cache_creation + cache_read

    if context_size == 0:
        return "0%"
    pct = (current_tokens / context_size) * 100
    return f"{pct:.0f}%"


def get_model_short_name(model: str) -> str:
    """Convert model ID to short display name."""
    model_lower = model.lower()
    if "opus" in model_lower:
        return "opus"
    if "sonnet" in model_lower:
        return "sonnet"
    if "haiku" in model_lower:
        return "haiku"
    return model[:10]


def get_branch_from_cwd(cwd: str) -> str:
    """Get git branch from working directory."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=1,
        )
        return result.stdout.strip() if result.returncode == 0 else ""
    except (subprocess.TimeoutExpired, OSError):
        return ""


def get_prompt_icon(prompt: str) -> str:
    """Get icon based on prompt type."""
    if prompt.startswith("/"):
        return "⚡"
    elif "?" in prompt:
        return "❓"
    elif any(
        word in prompt.lower()
        for word in ["create", "write", "add", "implement", "build"]
    ):
        return "💡"
    elif any(word in prompt.lower() for word in ["fix", "debug", "error", "issue"]):
        return "🐛"
    elif any(word in prompt.lower() for word in ["refactor", "improve", "optimize"]):
        return "♻️"
    else:
        return "💬"


def main() -> None:
    """Generate status line output."""
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        print(f"{DARK_GRAY}[err]{RESET}")
        return

    # Extract fields from Claude Code's actual JSON structure
    model_info = data.get("model", {})
    model_name = model_info.get("display_name") or model_info.get("id", "unknown")
    workspace = data.get("workspace", {})
    cwd = workspace.get("project_dir") or workspace.get("current_dir", "")
    context_window = data.get("context_window", {})

    # Build components
    model_short = get_model_short_name(model_name)
    branch = get_branch_from_cwd(cwd) if cwd else ""
    issue = extract_issue_id(branch)
    context_pct = format_context_usage(context_window)
    prompts = get_prompt_history()

    # Build status line parts
    parts = []

    # Issue number - dark blue with issue emoji
    if issue:
        parts.append(f"🔢 {DARK_BLUE}{issue}{RESET}")

    # Branch name - dark green with branch emoji
    if branch:
        parts.append(f"🌿 {DARK_GREEN}{truncate(branch, 30)}{RESET}")

    # Model name - dark gray with robot emoji
    parts.append(f"🤖 {DARK_GRAY}{model_short}{RESET}")

    # Context usage - cyan (yellow if high) with battery emoji
    pct_val = int(context_pct.rstrip("%"))
    if pct_val > 70:
        parts.append(f"🔋 {YELLOW}ctx: {context_pct}{RESET}")
    else:
        parts.append(f"🔋 {CYAN}ctx: {context_pct}{RESET}")

    # Prompts with icons - black (most recent), dark gray, medium gray
    if prompts:
        # Current prompt - black with icon
        current = prompts[-1]
        icon = get_prompt_icon(current)
        parts.append(
            f"{icon} {BLACK}{truncate(current, MAX_PROMPT_DISPLAY_LEN)}{RESET}"
        )

        # Previous prompt - dark gray with icon
        if len(prompts) > 1:
            prev = prompts[-2]
            prev_icon = get_prompt_icon(prev)
            parts.append(f"{prev_icon} {DARK_GRAY}{truncate(prev, 30)}{RESET}")

        # Older prompt - medium gray with icon
        if len(prompts) > 2:
            older = prompts[-3]
            older_icon = get_prompt_icon(older)
            parts.append(f"{older_icon} {MEDIUM_GRAY}{truncate(older, 25)}{RESET}")
    else:
        parts.append(f"{DARK_GRAY}💭 waiting{RESET}")

    print(" | ".join(parts))


if __name__ == "__main__":
    main()
