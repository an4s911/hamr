#!/bin/bash
# Script to scaffold a new Hamr plugin

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Get plugin name
if [ -z "$1" ]; then
    echo "Usage: $0 <plugin-name> [destination-directory]"
    echo ""
    echo "Examples:"
    echo "  $0 my-plugin                    # Creates in ~/.config/hamr/plugins/my-plugin"
    echo "  $0 my-plugin ./plugins          # Creates in ./plugins/my-plugin"
    echo ""
    exit 1
fi

PLUGIN_NAME="$1"
DEST_DIR="${2:-$HOME/.config/hamr/plugins}"

# Validate plugin name (lowercase, hyphens only)
if ! [[ "$PLUGIN_NAME" =~ ^[a-z0-9-]+$ ]]; then
    print_error "Plugin name must be lowercase letters, numbers, and hyphens only"
    exit 1
fi

# Create plugin directory
PLUGIN_DIR="$DEST_DIR/$PLUGIN_NAME"
if [ -d "$PLUGIN_DIR" ]; then
    print_error "Plugin directory already exists: $PLUGIN_DIR"
    exit 1
fi

mkdir -p "$PLUGIN_DIR"
print_success "Created directory: $PLUGIN_DIR"

# Convert plugin name to display name (Title Case)
DISPLAY_NAME=$(echo "$PLUGIN_NAME" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')

# Prompt for details
echo ""
print_info "Creating plugin: $DISPLAY_NAME"
echo ""

read -p "Description (what does it do?): " DESCRIPTION
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION="$DISPLAY_NAME plugin"
fi

read -p "Material icon name (default: extension): " ICON
if [ -z "$ICON" ]; then
    ICON="extension"
fi

# Create manifest.json
cat > "$PLUGIN_DIR/manifest.json" << EOF
{
  "name": "$DISPLAY_NAME",
  "description": "$DESCRIPTION",
  "icon": "$ICON",
  "supportedCompositors": ["*"],
  "frecency": "item"
}
EOF
print_success "Created manifest.json"

# Create handler.py
cat > "$PLUGIN_DIR/handler.py" << 'EOF'
#!/usr/bin/env python3
"""
Hamr Plugin Handler

This handler communicates with Hamr via JSON over stdin/stdout:
- Read JSON request from stdin
- Process the request
- Print JSON response to stdout
"""
import json
import sys


def main():
    # Read the JSON request from stdin
    input_data = json.load(sys.stdin)

    # Extract common fields
    step = input_data.get("step", "initial")
    query = input_data.get("query", "").strip()
    selected = input_data.get("selected", {})
    action = input_data.get("action", "")

    # Example items (replace with your own data)
    items = [
        {
            "id": "item1",
            "name": "Example Item 1",
            "description": "This is the first item",
            "icon": "star"
        },
        {
            "id": "item2",
            "name": "Example Item 2",
            "description": "This is the second item",
            "icon": "favorite"
        },
    ]

    # STEP: initial - Plugin just opened
    if step == "initial":
        print(json.dumps({
            "type": "results",
            "results": items,
            "placeholder": "Search items..."
        }))
        return

    # STEP: search - User is typing
    if step == "search":
        query_lower = query.lower()
        filtered = [
            item for item in items
            if query_lower in item["name"].lower()
            or query_lower in item.get("description", "").lower()
        ]
        print(json.dumps({
            "type": "results",
            "results": filtered
        }))
        return

    # STEP: action - User selected an item
    if step == "action":
        item_id = selected.get("id", "")

        # Perform action based on selected item
        print(json.dumps({
            "type": "execute",
            "notify": f"You selected: {item_id}",
            "close": True
        }))
        return


if __name__ == "__main__":
    main()
EOF
print_success "Created handler.py"

# Make handler executable
chmod +x "$PLUGIN_DIR/handler.py"
print_success "Made handler.py executable"

# Create test.sh (required for plugin contributions)
cat > "$PLUGIN_DIR/test.sh" << 'EOF'
#!/bin/bash
# Test script for plugin
# Required for plugin contributions

HANDLER="$(dirname "$0")/handler.py"

# Test initial step
echo "Testing initial step..."
RESULT=$(echo '{"step": "initial"}' | "$HANDLER")
if echo "$RESULT" | jq -e '.type == "results"' > /dev/null 2>&1; then
    echo "✓ Initial step works"
else
    echo "✗ Initial step failed"
    exit 1
fi

# Test search step
echo "Testing search step..."
RESULT=$(echo '{"step": "search", "query": "item"}' | "$HANDLER")
if echo "$RESULT" | jq -e '.type == "results"' > /dev/null 2>&1; then
    echo "✓ Search step works"
else
    echo "✗ Search step failed"
    exit 1
fi

# Test action step
echo "Testing action step..."
RESULT=$(echo '{"step": "action", "selected": {"id": "item1"}}' | "$HANDLER")
if echo "$RESULT" | jq -e '.type == "execute"' > /dev/null 2>&1; then
    echo "✓ Action step works"
else
    echo "✗ Action step failed"
    exit 1
fi

echo ""
echo "All tests passed!"
EOF
chmod +x "$PLUGIN_DIR/test.sh"
print_success "Created test.sh"

# Create README
cat > "$PLUGIN_DIR/README.md" << EOF
# $DISPLAY_NAME

$DESCRIPTION

## Usage

Open Hamr and search for "$PLUGIN_NAME" or use the trigger (if configured).

## Development

Test the plugin:
\`\`\`bash
./test.sh
\`\`\`

Test manually:
\`\`\`bash
echo '{"step": "initial"}' | ./handler.py | jq .
\`\`\`

## Documentation

- [Plugin Development Guide](https://hamr.run/plugins/)
- [Response Types](https://hamr.run/plugins/response-types/)
- [Visual Elements](https://hamr.run/plugins/visual-elements/)
EOF
print_success "Created README.md"

echo ""
print_success "Plugin created successfully!"
echo ""
print_info "Plugin location: $PLUGIN_DIR"
echo ""
echo "Next steps:"
echo "  1. Edit $PLUGIN_DIR/handler.py to implement your logic"
echo "  2. Test your plugin: cd $PLUGIN_DIR && ./test.sh"
echo "  3. Open Hamr and search for '$PLUGIN_NAME'"
echo ""
echo "Documentation:"
echo "  • Plugin Guide:    https://hamr.run/plugins/"
echo "  • Response Types:  https://hamr.run/plugins/response-types/"
echo "  • Visual Elements: https://hamr.run/plugins/visual-elements/"
echo ""
print_info "To view logs: journalctl --user -u hamr -f"
echo ""
