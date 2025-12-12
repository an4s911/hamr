#!/usr/bin/env python3
"""
Create Plugin - AI helper to create new workflow plugins for Hamr launcher

IMPORTANT: This plugin requires OpenCode CLI to be installed.
Install opencode: https://opencode.ai

This plugin provides a conversational interface where the AI will:
1. Ask clarifying questions about your plugin idea
2. Discuss the approach before creating
3. Only create the plugin when you confirm

If opencode is not available, this plugin will display an error message
with instructions for manual plugin creation.
"""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

# Check if opencode is available
OPENCODE_AVAILABLE = shutil.which("opencode") is not None

# Session storage file
SESSION_FILE = Path.home() / ".cache" / "hamr" / "create-plugin-session.json"


def get_actions_dir() -> Path:
    """Get the actions directory path"""
    config_home = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    return Path(config_home) / "hamr" / "actions"


def load_session() -> dict:
    """Load conversation session from cache"""
    if SESSION_FILE.exists():
        try:
            with open(SESSION_FILE) as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            pass
    return {"messages": [], "state": "initial"}


def save_session(session: dict):
    """Save conversation session to cache"""
    SESSION_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(SESSION_FILE, "w") as f:
        json.dump(session, f)


def clear_session():
    """Clear the conversation session"""
    if SESSION_FILE.exists():
        SESSION_FILE.unlink()


def get_system_prompt() -> str:
    """Get the system prompt for the AI"""
    actions_dir = get_actions_dir()
    return f"""You are a helpful assistant that helps users create plugins for the Hamr launcher.

Your role is to:
1. Understand what kind of plugin the user wants to create
2. Ask clarifying questions if the request is unclear
3. Discuss the approach and features before creating anything
4. Only create the plugin when the user confirms they're ready

IMPORTANT RULES:
- Do NOT create files or run commands until the user explicitly confirms
- Ask clarifying questions first (e.g., "What should happen when...", "Do you want it to...")
- When you understand the requirements, summarize what you'll create and ask "Should I create this plugin now?"
- Only when user says yes/confirm/create it/go ahead, then create the files

When creating a plugin:
- Create it in: {actions_dir}
- Use a descriptive folder name (lowercase, hyphens)
- Create manifest.json with name, description, and icon (Material Symbols icon name)
- Create handler.py following this protocol:

Input JSON (stdin): {{"step": "initial|search|action", "query": "...", "selected": {{"id": "..."}}}}

Output JSON (stdout) - one of:
- {{"type": "results", "results": [{{"id": "...", "name": "...", "description": "...", "icon": "..."}}]}}
- {{"type": "card", "card": {{"title": "...", "content": "markdown content", "markdown": true}}}}
- {{"type": "execute", "execute": {{"command": ["cmd", "args"], "close": true}}}}
- {{"type": "prompt", "prompt": {{"text": "Enter something..."}}}}

Make handler.py executable (chmod +x).

Look at existing plugins in {actions_dir} for examples."""


def chat_with_opencode(user_message: str, session: dict) -> tuple[bool, str]:
    """
    Send a message to OpenCode and get a response.
    Uses --continue to maintain conversation context.
    """
    try:
        # Build the conversation for opencode
        messages = session.get("messages", [])

        # First message includes system prompt
        if not messages:
            full_prompt = f"{get_system_prompt()}\n\nUser: {user_message}"
        else:
            full_prompt = user_message

        # Use --continue if we have a previous session
        cmd = ["opencode", "run", "--format", "json"]
        if messages:
            cmd.append("--continue")
        cmd.append(full_prompt)

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
            cwd=str(get_actions_dir()),
        )

        if result.returncode == 0:
            # Parse response
            response_text = extract_response_text(result.stdout)

            # Update session
            messages.append({"role": "user", "content": user_message})
            messages.append({"role": "assistant", "content": response_text})
            session["messages"] = messages
            save_session(session)

            return True, response_text
        else:
            return False, result.stderr or "OpenCode command failed"

    except subprocess.TimeoutExpired:
        return False, "Request timed out. Please try again."
    except subprocess.SubprocessError as e:
        return False, f"Error: {e}"


def extract_response_text(stdout: str) -> str:
    """Extract readable text from OpenCode's JSON output"""
    lines = stdout.strip().split("\n")
    text_parts = []

    for line in lines:
        if not line.strip():
            continue
        try:
            event = json.loads(line)
            event_type = event.get("type", "")

            # Handle "text" event type - content is in part.text
            if event_type == "text":
                part = event.get("part", {})
                text = part.get("text", "")
                if text:
                    text_parts.append(text)
            elif event_type == "message.completed":
                content = event.get("message", {}).get("content", "")
                if content:
                    text_parts.append(content)
        except json.JSONDecodeError:
            # Not JSON, might be plain text output
            if line.strip() and not line.startswith("{"):
                text_parts.append(line)

    # Deduplicate consecutive identical parts
    final_parts = []
    for part in text_parts:
        if not final_parts or final_parts[-1] != part:
            final_parts.append(part)

    return "\n".join(final_parts) if final_parts else ""


def main():
    input_data = json.load(sys.stdin)
    step = input_data.get("step", "initial")
    query = input_data.get("query", "").strip()
    selected = input_data.get("selected", {})

    # Check opencode availability
    if not OPENCODE_AVAILABLE:
        print(
            json.dumps(
                {
                    "type": "card",
                    "card": {
                        "title": "OpenCode Required",
                        "content": """**OpenCode CLI is required to use this plugin.**

OpenCode is an AI coding agent for the terminal.

## Installation

Install from the official website: https://opencode.ai

## Manual Plugin Creation

You can manually create plugins by:
1. Creating a folder in `~/.config/hamr/actions/`
2. Adding a `manifest.json` with name, description, and icon
3. Adding a `handler.py` script that reads JSON from stdin and outputs JSON to stdout

See existing plugins for examples.""",
                        "markdown": True,
                    },
                }
            )
        )
        return

    session = load_session()

    if step == "initial":
        # Check if we have an ongoing conversation
        if session.get("messages"):
            # Show option to continue or start fresh
            print(
                json.dumps(
                    {
                        "type": "results",
                        "inputMode": "submit",
                        "results": [
                            {
                                "id": "continue",
                                "name": "Continue previous conversation",
                                "description": "Resume where you left off",
                                "icon": "history",
                            },
                            {
                                "id": "new",
                                "name": "Start new conversation",
                                "description": "Clear history and start fresh",
                                "icon": "add_circle",
                            },
                            {
                                "id": "help",
                                "name": "How plugins work",
                                "description": "Learn about the plugin protocol",
                                "icon": "help",
                            },
                        ],
                        "placeholder": "Type your message and press Enter...",
                    }
                )
            )
        else:
            print(
                json.dumps(
                    {
                        "type": "results",
                        "inputMode": "submit",
                        "results": [
                            {
                                "id": "help",
                                "name": "How plugins work",
                                "description": "Learn about the plugin protocol",
                                "icon": "help",
                            },
                        ],
                        "placeholder": "Describe the plugin you want to create... (Enter to send)",
                    }
                )
            )
        return

    if step == "search":
        # With submit mode, this is only called when user presses Enter
        # So we process the query directly as a message to the AI
        if not query:
            # Empty submit - just show results
            print(
                json.dumps(
                    {
                        "type": "results",
                        "inputMode": "submit",
                        "results": [],
                        "placeholder": "Describe your plugin idea... (Enter to send)",
                    }
                )
            )
            return

        # Process the query as a message to the AI
        success, response = chat_with_opencode(query, session)

        if success:
            # Show AI response as card
            print(
                json.dumps(
                    {
                        "type": "card",
                        "card": {
                            "title": "AI",
                            "content": response
                            or "I'm ready to help you create a plugin. What would you like it to do?",
                            "markdown": True,
                        },
                        "inputMode": "submit",
                        "placeholder": "Type your reply... (Enter to send)",
                        "clearInput": True,
                    }
                )
            )
        else:
            print(
                json.dumps(
                    {
                        "type": "card",
                        "card": {
                            "title": "Error",
                            "content": f"**Failed to get response:**\n\n{response}",
                            "markdown": True,
                        },
                        "inputMode": "submit",
                        "placeholder": "Try again... (Enter to send)",
                        "clearInput": True,
                    }
                )
            )
        return

    if step == "action":
        item_id = selected.get("id", "")

        if item_id == "help":
            print(
                json.dumps(
                    {
                        "type": "card",
                        "card": {
                            "title": "Hamr Plugin Protocol",
                            "content": """## How Plugins Work

Plugins are folders in `~/.config/hamr/actions/` containing:

### manifest.json
```json
{
  "name": "My Plugin",
  "description": "What it does",
  "icon": "material_icon_name"
}
```

### handler.py (executable)
Communicates via JSON on stdin/stdout:

**Input:** `{"step": "initial|search|action", "query": "...", "selected": {"id": "..."}}`

**Output options:**
- `{"type": "results", "results": [...]}`
- `{"type": "card", "card": {"title": "...", "content": "...", "markdown": true}}`
- `{"type": "execute", "execute": {"command": [...], "close": true}}`

## Using This Plugin

Just describe what you want to create! The AI will:
1. Ask clarifying questions
2. Discuss the approach
3. Create the plugin when you confirm""",
                            "markdown": True,
                        },
                        "inputMode": "submit",
                        "placeholder": "Type your plugin idea... (Enter to send)",
                    }
                )
            )
            return

        if item_id == "new":
            clear_session()
            session = {"messages": [], "state": "initial"}
            print(
                json.dumps(
                    {
                        "type": "results",
                        "inputMode": "submit",
                        "results": [],
                        "placeholder": "Describe the plugin you want to create... (Enter to send)",
                        "clearInput": True,
                    }
                )
            )
            return

        if item_id == "continue":
            # Show last AI message as card
            messages = session.get("messages", [])
            last_ai_msg = ""
            for msg in reversed(messages):
                if msg.get("role") == "assistant":
                    last_ai_msg = msg.get("content", "")
                    break

            if last_ai_msg:
                print(
                    json.dumps(
                        {
                            "type": "card",
                            "card": {
                                "title": "Continuing Conversation",
                                "content": last_ai_msg,
                                "markdown": True,
                            },
                            "inputMode": "submit",
                            "placeholder": "Type your reply... (Enter to send)",
                            "clearInput": True,
                        }
                    )
                )
            else:
                print(
                    json.dumps(
                        {
                            "type": "results",
                            "inputMode": "submit",
                            "results": [],
                            "placeholder": "Continue describing your plugin... (Enter to send)",
                        }
                    )
                )
            return


if __name__ == "__main__":
    main()
