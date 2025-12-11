# User Actions & Workflows

This directory contains custom actions and workflows for the Quickshell launcher.

## Directory Structure

```
~/.config/hamr/actions/
├── AGENTS.md           # This file
├── simple-script       # Simple action (executable script)
├── workflow-name/      # Multi-step workflow (folder)
│   ├── manifest.json   # Workflow metadata
│   └── handler.py      # Workflow handler script
```

## Simple Actions (Scripts)

Single executable scripts that run when selected.

### Creating a Simple Action

1. Create an executable file (no extension needed):
   ```bash
   touch ~/.config/hamr/actions/my-action
   chmod +x ~/.config/hamr/actions/my-action
   ```

2. Add your script content:
   ```bash
   #!/bin/bash
   # Do something
   notify-send "Hello from my action!"
   ```

3. The action appears in search as `/my-action`

### Examples

**toggle-dark** - Toggle dark mode:
```bash
#!/bin/bash
# Toggle between light and dark theme
```

**screenshot** - Take a screenshot:
```bash
#!/bin/bash
grim -g "$(slurp)" - | wl-copy
```

## Multi-Step Workflows (Folders)

Interactive workflows with multiple steps, navigation, and rich UI.

### Creating a Workflow

1. Create a folder:
   ```bash
   mkdir ~/.config/hamr/actions/my-workflow
   ```

2. Create `manifest.json`:
   ```json
   {
     "name": "My Workflow",
     "description": "Does something cool",
     "icon": "extension"
   }
   ```

3. Create `handler.py` (must be executable):
   ```bash
   touch ~/.config/hamr/actions/my-workflow/handler.py
   chmod +x ~/.config/hamr/actions/my-workflow/handler.py
   ```

4. Reload Quickshell to detect new workflow

### JSON Protocol

**Input (stdin):**
```json
{
  "step": "initial|search|action",
  "query": "user search text",
  "selected": {"id": "selected-item-id"},
  "action": "action-button-id",
  "session": "unique-session-id"
}
```

**Output (stdout) - one of:**

```python
# Show results list (stays open for multi-turn)
# Optional: placeholder, clearInput, context
{"type": "results", "results": [...], "placeholder": "Search...", "clearInput": true, "context": "edit:item-id"}

# Show rich card content (stays open)
{"type": "card", "card": {"title": "...", "content": "...", "markdown": true}}

# Execute command (with optional history tracking)
{"type": "execute", "execute": {"command": ["cmd", "arg"], "notify": "message", "close": true, "name": "Action Name", "icon": "icon", "thumbnail": "/path"}}

# Open image browser UI (for image/wallpaper selection)
{"type": "imageBrowser", "imageBrowser": {"directory": "~/Pictures", "title": "Select Image", "actions": [{"id": "set_dark", "name": "Set Dark", "icon": "dark_mode"}]}}

# Show prompt text
{"type": "prompt", "prompt": {"text": "Enter something..."}}

# Show error
{"type": "error", "message": "Error description"}
```

### Result Object Properties

```python
{
    "id": "unique-id",           # Required - used for selection
    "name": "Display Name",      # Required - main text
    "description": "Subtext",    # Optional - shown below name
    "icon": "material_icon",     # Optional - Material icon name
    "thumbnail": "/path/to/img", # Optional - image (overrides icon)
    "verb": "Open",              # Optional - hover action text
    "actions": [                 # Optional - action buttons
        {"id": "action-id", "name": "Action Name", "icon": "icon_name"}
    ]
}
```

### Step Types

| Step | When Called | Use Case |
|------|-------------|----------|
| `initial` | Workflow starts | Show initial list/prompt |
| `search` | User types in search box | Filter/search results |
| `action` | User clicks item or action button | Handle selection, navigate, or execute |

### Handler Template

```python
#!/usr/bin/env python3
import json
import sys

def main():
    input_data = json.load(sys.stdin)
    step = input_data.get("step", "initial")
    query = input_data.get("query", "").strip()
    selected = input_data.get("selected", {})
    action = input_data.get("action", "")

    if step == "initial":
        # Show initial results
        print(json.dumps({
            "type": "results",
            "results": [
                {"id": "item1", "name": "First Item", "icon": "star"},
                {"id": "item2", "name": "Second Item", "icon": "favorite"},
            ]
        }))
        return

    if step == "search":
        # Filter by query
        # ... filter logic ...
        print(json.dumps({"type": "results", "results": filtered_results}))
        return

    if step == "action":
        item_id = selected.get("id", "")
        
        # Handle back navigation
        if item_id == "__back__":
            print(json.dumps({"type": "results", "results": initial_results}))
            return
        
        # Handle final action - close workflow
        if item_id == "do-something":
            print(json.dumps({
                "type": "execute",
                "execute": {
                    "command": ["notify-send", "Done!"],
                    "close": True
                }
            }))
            return
        
        # Handle drill-down - show detail view (multi-turn)
        print(json.dumps({
            "type": "results",
            "results": [
                {"id": "__back__", "name": "Back", "icon": "arrow_back"},
                {"id": "do-something", "name": "Execute Action", "icon": "play_arrow"},
            ]
        }))

if __name__ == "__main__":
    main()
```

### Multi-Turn Navigation Pattern

```python
# Back button - always include in detail views
{"id": "__back__", "name": "Back to list", "icon": "arrow_back"}

# Use prefixed IDs to distinguish actions in detail view
{"id": "open:/path/to/file", "name": "Open", "icon": "open_in_new"}
{"id": "copy:/path/to/file", "name": "Copy Path", "icon": "content_copy"}
{"id": "delete:/path/to/file", "name": "Delete", "icon": "delete"}

# Then parse in handler:
if item_id.startswith("open:"):
    path = item_id.split(":", 1)[1]
    # ... handle open
```

### Card Display (Rich Content)

```python
# Show markdown-formatted content
print(json.dumps({
    "type": "card",
    "card": {
        "title": "Definition",
        "content": "**word** /wərd/\n\n*noun*\n1. A single unit of language",
        "markdown": True
    }
}))
```

### Execute Options

```python
{
    "type": "execute",
    "execute": {
        "command": ["cmd", "arg1", "arg2"],  # Command to run
        "notify": "Success message",          # Optional notification
        "close": True,                        # True = close launcher, False = stay open
        # History tracking (optional - if provided, action becomes fuzzy-searchable)
        "name": "Open document.pdf",          # Display name for history
        "icon": "description",                # Material icon for history entry
        "thumbnail": "/path/to/preview.png"   # Thumbnail for history entry
    }
}
```

### History Tracking

When `name` is provided in an `execute` response, the action is saved to search history and becomes fuzzy-searchable. Users can type part of the action name to quickly repeat it.

**When to use history tracking:**
- File operations: "Open document.pdf", "Copy path: ~/Downloads/file.txt"
- Shell commands: "Run: git status", "Run: docker ps"
- Searches: "Search Google: quickshell", "Define: serendipity"
- Media actions: "Set wallpaper: sunset.png", "Play: favorite-song.mp3"

**When NOT to use history tracking:**
- CRUD operations on stateful data (todo add/toggle/delete - state is ephemeral)
- One-time confirmations (wipe clipboard, delete all)
- AI chat responses (not repeatable)

**Best practices:**
- Keep `name` concise but descriptive: "Open: file.txt" not "Opening the file file.txt"
- Include the action verb: "Run:", "Copy:", "Open:", "Define:", "Search:"
- Truncate long content: `name[:50] + "..."` for commands/text
- Use appropriate icons that match the action type

## Material Icons

Use any icon from [Material Symbols](https://fonts.google.com/icons).

Common icons:
- Navigation: `arrow_back`, `home`, `menu`
- Actions: `open_in_new`, `content_copy`, `delete`, `edit`, `save`
- Files: `folder`, `description`, `image`, `video_file`
- UI: `search`, `settings`, `star`, `favorite`, `check`

## Example Workflows

### Files (`files/`)
- Fuzzy file search using fd + fzf
- Triggered by `~` prefix in main search
- Shows recent files on initial
- Actions: Open, Open folder, Copy path, Delete (trash)
- Thumbnails for images
- File type icons (code, docs, images, etc.)

### Quicklinks (`quicklinks/`)
- Search the web with predefined quicklinks
- Add new quicklinks (name + URL with `{query}` placeholder)
- Edit existing quicklink URLs
- Delete quicklinks
- Custom placeholders for each step

### Shell History (`shell/`)
- Search and execute shell commands from history
- Actions: Run (floating), Run (tiled), Copy

### Dictionary (`dict/`)
- Look up word definitions
- Shows card with markdown-formatted definition

### Pictures (`pictures/`)
- Browse images in ~/Pictures
- Thumbnails in list view
- Detail view with Open, Copy, Delete actions
- Multi-turn navigation (list → detail → back)

### Wallpaper (`wallpaper/`)
- Uses `imageBrowser` response type for rich UI
- Browse wallpapers with thumbnails
- Dark/Light mode action buttons
- Sets wallpaper via switchwall.sh

## Keyboard Navigation

Users can navigate workflows with:
- **Ctrl+J** - Move down
- **Ctrl+K** - Move up  
- **Ctrl+L** or **Enter** - Select current item
- **Escape** - Exit workflow (then close launcher)

## Response Options

### Results Response

```python
{
    "type": "results",
    "results": [...],
    "placeholder": "Custom placeholder...",  # Optional: search bar placeholder text
    "clearInput": True,                      # Optional: clear search input
    "context": "__edit__:item-id"            # Optional: set context for search calls
}
```

- **placeholder**: Custom placeholder text for search bar (e.g., "Enter URL...", "Search files...")
- **clearInput**: Clear the search input (useful when entering new mode)
- **context**: Set `lastSelectedItem` for subsequent search calls. Useful when entering edit mode - the search handler can check this context to know what item is being edited.

### Image Browser Response

Opens a rich image browser UI with thumbnails, directory navigation, and custom actions.

```python
{
    "type": "imageBrowser",
    "imageBrowser": {
        "directory": "~/Pictures/Wallpapers",  # Initial directory (~ expanded)
        "title": "Select Wallpaper",           # Title shown in sidebar
        "actions": [                           # Custom action buttons in toolbar
            {"id": "set_dark", "name": "Set (Dark Mode)", "icon": "dark_mode"},
            {"id": "set_light", "name": "Set (Light Mode)", "icon": "light_mode"},
        ]
    }
}
```

When user selects an image, handler receives:

```python
{
    "step": "action",
    "selected": {
        "id": "imageBrowser",              # Always "imageBrowser"
        "path": "/full/path/to/image.jpg", # Selected image path
        "action": "set_dark"               # ID of clicked action
    }
}
```

**Use cases:**
- Wallpaper selector with dark/light mode
- Image picker for any purpose
- Avatar/profile picture selection
- Screenshot browser

### IPC Calls (Refresh UI Components)

Workflows can call Quickshell's IPC directly to refresh UI components (like the todo sidebar) after making changes.

**Call IPC from handler:**
```python
import subprocess

def call_hamr_ipc(target, method, *args):
    """Call Hamr IPC method"""
    cmd = ["qs", "-c", "hamr", "ipc", "call", target, method] + list(args)
    subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
```

**Available IPC targets:**
```bash
# List all available targets
qs -c hamr ipc show
```

Common targets:
- `hamr` - Main launcher
  - `toggle()`, `open()`, `close()`
  - `openWith(prefix)` - Open with specific prefix
  - `workflow(name)` - Start specific workflow

**Use cases:**
- Trigger launcher from external scripts
- Open launcher with specific mode/workflow

## Tips

1. **Always handle `__back__`** - Users expect back navigation
2. **Use `close: True`** only for final actions
3. **Keep results under 50 items** - Performance
4. **Use thumbnails sparingly** - They load images
5. **Test with edge cases** - Empty results, errors, special characters
6. **Use `console.warn` for debugging** - Check with `journalctl --user -f`
7. **Use `placeholder` for context** - Helps users know what to type
8. **Use `context` for edit modes** - Preserve selected item across search calls
9. **Use `ipc` to refresh UI** - Update sidebars/widgets after data changes
