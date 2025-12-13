#!/usr/bin/env python3
"""
Notes workflow handler - quick notes with CRUD operations.
Features: list, add, view, edit, delete, copy
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

# Notes file location
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
NOTES_FILE = CONFIG_DIR / "hamr" / "notes.json"


def load_notes() -> list[dict]:
    """Load notes from file"""
    if not NOTES_FILE.exists():
        return []
    try:
        with open(NOTES_FILE) as f:
            data = json.load(f)
            return data.get("notes", [])
    except (json.JSONDecodeError, IOError):
        return []


def save_notes(notes: list[dict]) -> bool:
    """Save notes to file"""
    try:
        NOTES_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(NOTES_FILE, "w") as f:
            json.dump({"notes": notes}, f, indent=2)
        return True
    except IOError:
        return False


def generate_id() -> str:
    """Generate a unique ID for a note"""
    return f"note_{int(time.time() * 1000)}"


def truncate(text: str, max_len: int = 60) -> str:
    """Truncate text with ellipsis"""
    if len(text) <= max_len:
        return text
    return text[: max_len - 3] + "..."


def get_note_results(notes: list[dict], show_add: bool = True) -> list[dict]:
    """Convert notes to result format"""
    results = []

    if show_add:
        results.append(
            {
                "id": "__add__",
                "name": "Add new note...",
                "icon": "add_circle",
                "description": "Create a new note",
            }
        )

    # Sort notes by updated time (most recent first)
    sorted_notes = sorted(notes, key=lambda n: n.get("updated", 0), reverse=True)

    for note in sorted_notes:
        note_id = note.get("id", "")
        title = note.get("title", "Untitled")
        content = note.get("content", "")

        # Show first line of content as description
        first_line = content.split("\n")[0] if content else ""
        description = truncate(first_line, 50) if first_line else "Empty note"

        results.append(
            {
                "id": note_id,
                "name": title,
                "icon": "sticky_note_2",
                "description": description,
                "actions": [
                    {"id": "view", "name": "View", "icon": "visibility"},
                    {"id": "edit", "name": "Edit", "icon": "edit"},
                    {"id": "copy", "name": "Copy", "icon": "content_copy"},
                    {"id": "delete", "name": "Delete", "icon": "delete"},
                ],
            }
        )

    if not notes and show_add:
        results.append(
            {
                "id": "__empty__",
                "name": "No notes yet",
                "icon": "info",
                "description": "Click 'Add new note' to get started",
            }
        )

    return results


def filter_notes(query: str, notes: list[dict]) -> list[dict]:
    """Filter notes by title or content"""
    if not query:
        return notes
    query_lower = query.lower()
    return [
        n
        for n in notes
        if query_lower in n.get("title", "").lower()
        or query_lower in n.get("content", "").lower()
    ]


def format_note_card(note: dict) -> str:
    """Format note as markdown for card display"""
    title = note.get("title", "Untitled")
    content = note.get("content", "")
    return f"## {title}\n\n{content}"


def respond(response: dict):
    """Send JSON response"""
    print(json.dumps(response))


def main():
    input_data = json.load(sys.stdin)
    step = input_data.get("step", "initial")
    query = input_data.get("query", "").strip()
    selected = input_data.get("selected", {})
    action = input_data.get("action", "")
    context = input_data.get("context", "")

    notes = load_notes()

    # ===== INITIAL: Show notes list =====
    if step == "initial":
        respond(
            {
                "type": "results",
                "results": get_note_results(notes),
                "inputMode": "realtime",
                "placeholder": "Search notes or add new...",
            }
        )
        return

    # ===== SEARCH: Context-dependent search =====
    if step == "search":
        # Add mode - entering title (submit mode)
        if context == "__add_title__":
            if query:
                # Move to content entry
                respond(
                    {
                        "type": "results",
                        "inputMode": "submit",
                        "clearInput": True,
                        "context": f"__add_content__:{query}",
                        "placeholder": "Enter note content (Enter to save)",
                        "results": [
                            {"id": "__back__", "name": "Cancel", "icon": "arrow_back"},
                            {
                                "id": "__info__",
                                "name": f"Title: {query}",
                                "icon": "title",
                                "description": "Now enter the note content",
                            },
                        ],
                    }
                )
            else:
                respond(
                    {
                        "type": "results",
                        "inputMode": "submit",
                        "context": "__add_title__",
                        "placeholder": "Enter note title (Enter to continue)",
                        "results": [
                            {"id": "__back__", "name": "Cancel", "icon": "arrow_back"}
                        ],
                    }
                )
            return

        # Add mode - entering content (submit mode)
        if context.startswith("__add_content__:"):
            title = context.split(":", 1)[1]
            if query:
                # Save the note
                new_note = {
                    "id": generate_id(),
                    "title": title,
                    "content": query,
                    "created": int(time.time() * 1000),
                    "updated": int(time.time() * 1000),
                }
                notes.append(new_note)
                if save_notes(notes):
                    respond(
                        {
                            "type": "results",
                            "results": get_note_results(notes),
                            "inputMode": "realtime",
                            "clearInput": True,
                            "context": "",
                            "placeholder": "Search notes or add new...",
                        }
                    )
                else:
                    respond({"type": "error", "message": "Failed to save note"})
            else:
                respond(
                    {
                        "type": "results",
                        "inputMode": "submit",
                        "context": context,
                        "placeholder": "Enter note content (Enter to save)",
                        "results": [
                            {"id": "__back__", "name": "Cancel", "icon": "arrow_back"},
                            {
                                "id": "__info__",
                                "name": f"Title: {title}",
                                "icon": "title",
                                "description": "Type note content above",
                            },
                        ],
                    }
                )
            return

        # Edit title mode (submit mode)
        if context.startswith("__edit_title__:"):
            note_id = context.split(":", 1)[1]
            note = next((n for n in notes if n.get("id") == note_id), None)
            if not note:
                respond({"type": "error", "message": "Note not found"})
                return

            if query:
                # Move to content edit
                respond(
                    {
                        "type": "results",
                        "inputMode": "submit",
                        "clearInput": True,
                        "context": f"__edit_content__:{note_id}:{query}",
                        "placeholder": "Edit note content (Enter to save)",
                        "results": [
                            {"id": "__back__", "name": "Cancel", "icon": "arrow_back"},
                            {
                                "id": "__info__",
                                "name": f"New title: {query}",
                                "icon": "title",
                                "description": "Now edit the content",
                            },
                            {
                                "id": "__current__",
                                "name": f"Current content: {truncate(note.get('content', ''), 40)}",
                                "icon": "notes",
                            },
                        ],
                    }
                )
            else:
                respond(
                    {
                        "type": "results",
                        "inputMode": "submit",
                        "context": context,
                        "placeholder": "Edit note title (Enter to continue)",
                        "results": [
                            {"id": "__back__", "name": "Cancel", "icon": "arrow_back"},
                            {
                                "id": "__current__",
                                "name": f"Current: {note.get('title', '')}",
                                "icon": "info",
                                "description": "Type new title above",
                            },
                        ],
                    }
                )
            return

        # Edit content mode (submit mode)
        if context.startswith("__edit_content__:"):
            parts = context.split(":", 2)
            note_id = parts[1]
            new_title = parts[2] if len(parts) > 2 else ""
            note = next((n for n in notes if n.get("id") == note_id), None)
            if not note:
                respond({"type": "error", "message": "Note not found"})
                return

            if query:
                # Save edits
                note["title"] = new_title
                note["content"] = query
                note["updated"] = int(time.time() * 1000)
                if save_notes(notes):
                    respond(
                        {
                            "type": "results",
                            "results": get_note_results(notes),
                            "inputMode": "realtime",
                            "clearInput": True,
                            "context": "",
                            "placeholder": "Search notes or add new...",
                        }
                    )
                else:
                    respond({"type": "error", "message": "Failed to save note"})
            else:
                respond(
                    {
                        "type": "results",
                        "inputMode": "submit",
                        "context": context,
                        "placeholder": "Edit note content (Enter to save)",
                        "results": [
                            {"id": "__back__", "name": "Cancel", "icon": "arrow_back"},
                            {
                                "id": "__info__",
                                "name": f"Title: {new_title}",
                                "icon": "title",
                            },
                            {
                                "id": "__current__",
                                "name": f"Current: {truncate(note.get('content', ''), 40)}",
                                "icon": "info",
                                "description": "Type new content above",
                            },
                        ],
                    }
                )
            return

        # Normal search: filter notes
        filtered = filter_notes(query, notes)
        results = []

        if query:
            # Show add option when searching
            results.append(
                {
                    "id": f"__add_quick__:{query}",
                    "name": f"Create note: {query}",
                    "icon": "add_circle",
                    "description": "Quick create with this as title",
                }
            )

        results.extend(get_note_results(filtered, show_add=not query))

        respond(
            {
                "type": "results",
                "results": results,
                "inputMode": "realtime",
                "placeholder": "Search notes or add new...",
            }
        )
        return

    # ===== ACTION: Handle clicks =====
    if step == "action":
        item_id = selected.get("id", "")

        # Back navigation
        if item_id == "__back__":
            respond(
                {
                    "type": "results",
                    "results": get_note_results(notes),
                    "inputMode": "realtime",
                    "clearInput": True,
                    "context": "",
                    "placeholder": "Search notes or add new...",
                }
            )
            return

        # Info items - not actionable
        if item_id in ("__info__", "__current__", "__empty__"):
            return

        # Start adding new note
        if item_id == "__add__":
            respond(
                {
                    "type": "results",
                    "inputMode": "submit",
                    "clearInput": True,
                    "context": "__add_title__",
                    "placeholder": "Enter note title (Enter to continue)",
                    "results": [
                        {"id": "__back__", "name": "Cancel", "icon": "arrow_back"},
                        {
                            "id": "__info__",
                            "name": "Step 1: Enter a title",
                            "icon": "title",
                            "description": "Then you'll add the content",
                        },
                    ],
                }
            )
            return

        # Quick add from search
        if item_id.startswith("__add_quick__:"):
            title = item_id.split(":", 1)[1]
            respond(
                {
                    "type": "results",
                    "inputMode": "submit",
                    "clearInput": True,
                    "context": f"__add_content__:{title}",
                    "placeholder": "Enter note content (Enter to save)",
                    "results": [
                        {"id": "__back__", "name": "Cancel", "icon": "arrow_back"},
                        {
                            "id": "__info__",
                            "name": f"Title: {title}",
                            "icon": "title",
                            "description": "Now enter the note content",
                        },
                    ],
                }
            )
            return

        # Find the note
        note = next((n for n in notes if n.get("id") == item_id), None)
        if not note:
            respond({"type": "error", "message": f"Note not found: {item_id}"})
            return

        # View action (default) - show as card
        if action == "view" or not action:
            respond(
                {
                    "type": "card",
                    "card": {
                        "content": format_note_card(note),
                        "markdown": True,
                        "actions": [
                            {"id": "edit", "name": "Edit", "icon": "edit"},
                            {"id": "copy", "name": "Copy", "icon": "content_copy"},
                            {"id": "delete", "name": "Delete", "icon": "delete"},
                            {"id": "back", "name": "Back", "icon": "arrow_back"},
                        ],
                    },
                    "context": item_id,  # Store note ID for card actions
                }
            )
            return

        # Edit action
        if action == "edit":
            respond(
                {
                    "type": "results",
                    "inputMode": "submit",
                    "clearInput": True,
                    "context": f"__edit_title__:{item_id}",
                    "placeholder": "Edit note title (Enter to continue)",
                    "results": [
                        {"id": "__back__", "name": "Cancel", "icon": "arrow_back"},
                        {
                            "id": "__current__",
                            "name": f"Current: {note.get('title', '')}",
                            "icon": "info",
                            "description": "Type new title above",
                        },
                    ],
                }
            )
            return

        # Copy action
        if action == "copy":
            content = f"{note.get('title', '')}\n\n{note.get('content', '')}"
            subprocess.run(["wl-copy", content], check=False)
            respond(
                {
                    "type": "execute",
                    "execute": {
                        "notify": f"Note '{truncate(note.get('title', ''), 20)}' copied",
                        "close": True,
                    },
                }
            )
            return

        # Delete action
        if action == "delete":
            notes = [n for n in notes if n.get("id") != item_id]
            if save_notes(notes):
                respond(
                    {
                        "type": "results",
                        "results": get_note_results(notes),
                        "inputMode": "realtime",
                        "clearInput": True,
                        "context": "",
                        "placeholder": "Search notes or add new...",
                    }
                )
            else:
                respond({"type": "error", "message": "Failed to delete note"})
            return

        # Card actions (when viewing a note)
        if action == "back":
            respond(
                {
                    "type": "results",
                    "results": get_note_results(notes),
                    "inputMode": "realtime",
                    "clearInput": True,
                    "context": "",
                    "placeholder": "Search notes or add new...",
                }
            )
            return

    # Unknown step
    respond({"type": "error", "message": f"Unknown step: {step}"})


if __name__ == "__main__":
    main()
