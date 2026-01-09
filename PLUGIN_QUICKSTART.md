# Quick Start: Creating a Hamr Plugin

This guide will get you started creating a new plugin in under 5 minutes.

## Prerequisites

- Hamr launcher installed
- Python 3.9+ (or another language for your handler)
- `jq` (for testing)

## Two Ways to Create a Plugin

### Option 1: Use the Scaffolding Script (Recommended)

The quickest way to create a plugin:

```bash
# From the hamr repository
./scripts/create-plugin.sh my-plugin

# Or create in a custom location
./scripts/create-plugin.sh my-plugin ./plugins
```

This creates a complete plugin structure with:
- `manifest.json` - Plugin metadata
- `handler.py` - Main plugin logic (with examples)
- `test.sh` - Test script
- `README.md` - Documentation

Then:
1. Edit `handler.py` to implement your logic
2. Test: `cd ~/.config/hamr/plugins/my-plugin && ./test.sh`
3. Open Hamr and search for your plugin!

### Option 2: Use the AI Plugin Creator

If you have [OpenCode](https://opencode.ai) installed, use the interactive AI helper:

1. Open Hamr
2. Search for `/create-plugin`
3. Describe what you want to build
4. The AI will ask clarifying questions and create the plugin for you

### Option 3: Manual Creation

Create the plugin structure yourself:

```bash
# Create plugin directory
mkdir -p ~/.config/hamr/plugins/my-plugin
cd ~/.config/hamr/plugins/my-plugin
```

Create `manifest.json`:
```json
{
  "name": "My Plugin",
  "description": "What it does",
  "icon": "star",
  "supportedCompositors": ["*"]
}
```

Create `handler.py`:
```python
#!/usr/bin/env python3
import json
import sys

def main():
    input_data = json.load(sys.stdin)
    step = input_data.get("step", "initial")
    
    if step == "initial":
        print(json.dumps({
            "type": "results",
            "results": [
                {"id": "1", "name": "Item 1", "icon": "star"},
                {"id": "2", "name": "Item 2", "icon": "favorite"}
            ]
        }))

if __name__ == "__main__":
    main()
```

Make it executable:
```bash
chmod +x handler.py
```

## Testing Your Plugin

### Quick Test
```bash
# Test initial step
echo '{"step": "initial"}' | ./handler.py | jq .

# Test search step
echo '{"step": "search", "query": "test"}' | ./handler.py | jq .

# Test action step
echo '{"step": "action", "selected": {"id": "1"}}' | ./handler.py | jq .
```

### Run Test Suite
```bash
./test.sh
```

### View Logs
```bash
# If running via systemd
journalctl --user -u hamr -f

# If running in dev mode
# Logs appear directly in terminal
```

## Development Workflow

1. **Make changes** to `handler.py`
2. **Test immediately**: `./test.sh`
3. **Open Hamr** - it auto-reloads when plugin files change (in dev mode)
4. **Check logs** if something doesn't work

### Dev Mode (Recommended)

For the best development experience:

```bash
# From the hamr repository
cd ~/path/to/hamr
./dev
```

Dev mode provides:
- Auto-reload on file changes
- Live logs in the terminal
- Better error messages

## Common Plugin Patterns

### Results List
Show a list of items that users can select:
```python
{
    "type": "results",
    "results": [
        {
            "id": "unique-id",
            "name": "Display Name",
            "description": "Subtitle text",
            "icon": "material_icon_name"
        }
    ],
    "placeholder": "Search hint..."
}
```

### Execute Action
Perform an action (copy, open URL, notify, etc.):
```python
{
    "type": "execute",
    "notify": "Action completed!",
    "copy": "text to clipboard",
    "openUrl": "https://example.com",
    "close": True
}
```

### Rich Card
Display formatted content:
```python
{
    "type": "card",
    "card": {
        "title": "Title",
        "content": "**Markdown** content here",
        "markdown": True
    }
}
```

## File Structure

Your plugin directory should look like:

```
~/.config/hamr/plugins/my-plugin/
├── manifest.json    # Required - Plugin metadata
├── handler.py       # Required - Main logic (can be any language)
├── test.sh         # Recommended - Test script
└── README.md       # Optional - Documentation
```

## Next Steps

Once you have the basics working, explore advanced features:

- **[Full Plugin Guide](docs/plugins/index.md)** - Complete tutorial with examples
- **[Response Types](docs/plugins/response-types.md)** - All response types (results, card, form, imageBrowser, etc.)
- **[Visual Elements](docs/plugins/visual-elements.md)** - Sliders, switches, badges, gauges, progress bars
- **[Advanced Features](docs/plugins/advanced-features.md)** - Pattern matching, daemon mode, indexing
- **[API Reference](docs/plugins/api-reference.md)** - Complete schema reference
- **[Cheat Sheet](docs/plugins/cheatsheet.md)** - Quick reference for common patterns

## Built-in Examples

Study these plugins for real-world examples:

| Plugin | Good For Learning |
|--------|------------------|
| `apps/` | File parsing, categories, icons |
| `calculate/` | Pattern matching, instant results |
| `timer/` | Daemon mode, real-time updates |
| `todo/` | File watching, CRUD operations |
| `clipboard/` | Thumbnails, filters |
| `emoji/` | Large datasets, grid browser |

## Troubleshooting

**Plugin doesn't appear in Hamr:**
- Check `supportedCompositors` is set in manifest.json
- Ensure handler is executable: `chmod +x handler.py`
- View logs: `journalctl --user -u hamr -f`

**Plugin shows error:**
- Test manually: `echo '{"step": "initial"}' | ./handler.py`
- Check JSON is valid: `echo '{"step": "initial"}' | ./handler.py | jq .`
- Check logs for error details

**Changes not appearing:**
- Run in dev mode for auto-reload: `./dev`
- Otherwise, restart Hamr: `systemctl --user restart hamr`

## Getting Help

- **Documentation:** https://hamr.run/plugins/
- **Examples:** Browse `~/.local/share/hamr/plugins/` (built-in plugins)
- **Issues:** https://github.com/an4s911/hamr/issues

Happy plugin building! 🚀
