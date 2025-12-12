#!/bin/bash
set -e

# Claude Code Hacker Elite Statusline Installer
# This script sets up the statusline automatically

echo "🚀 Claude Code Hacker Elite Statusline Installer"
echo "================================================="
echo ""

# Check for required dependencies
echo "Checking dependencies..."

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is not installed"
    echo "   Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi
echo "✓ jq found"

# Check for git
if ! command -v git &> /dev/null; then
    echo "⚠️  Warning: git not found (git features will be disabled)"
else
    echo "✓ git found"
fi

echo ""

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUSLINE_SCRIPT="${SCRIPT_DIR}/statusline.sh"
TARGET_SCRIPT="${HOME}/.claude/statusline-command.sh"
SETTINGS_FILE="${HOME}/.claude/settings.json"
ACCOUNT_CONFIG="${HOME}/.claude/statusline-account.txt"

# Check if statusline script exists
if [ ! -f "$STATUSLINE_SCRIPT" ]; then
    echo "❌ Error: statusline.sh not found in ${SCRIPT_DIR}"
    exit 1
fi

echo "Installing statusline..."

# Backup existing statusline if it exists
if [ -f "$TARGET_SCRIPT" ]; then
    BACKUP="${TARGET_SCRIPT}.backup.$(date +%Y%m%d-%H%M%S)"
    echo "📦 Backing up existing statusline to: ${BACKUP}"
    cp "$TARGET_SCRIPT" "$BACKUP"
fi

# Copy statusline script
echo "📝 Copying statusline script..."
cp "$STATUSLINE_SCRIPT" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"
echo "✓ Statusline script installed to ${TARGET_SCRIPT}"

# Create account config if it doesn't exist
if [ ! -f "$ACCOUNT_CONFIG" ]; then
    echo ""
    echo "Setting up account type..."
    echo "Which Claude plan are you using?"
    echo "  1) Pro"
    echo "  2) Max"
    echo "  3) Team"
    echo "  4) API (ANTHROPIC_API_KEY)"
    echo ""
    read -p "Enter choice [1-4] (default: 2): " choice

    case "$choice" in
        1)
            echo "Pro" > "$ACCOUNT_CONFIG"
            echo "✓ Set account type to: Pro"
            ;;
        3)
            echo "Team" > "$ACCOUNT_CONFIG"
            echo "✓ Set account type to: Team"
            ;;
        4)
            echo "API" > "$ACCOUNT_CONFIG"
            echo "✓ Set account type to: API"
            ;;
        2|*)
            echo "Max" > "$ACCOUNT_CONFIG"
            echo "✓ Set account type to: Max"
            ;;
    esac
else
    CURRENT_TYPE=$(cat "$ACCOUNT_CONFIG" | tr -d '[:space:]')
    echo "✓ Account type already configured: ${CURRENT_TYPE}"
fi

echo ""

# Update settings.json
if [ -f "$SETTINGS_FILE" ]; then
    echo "Updating Claude Code settings..."

    # Check if statusLine already exists
    if grep -q '"statusLine"' "$SETTINGS_FILE"; then
        echo "⚠️  statusLine already configured in settings.json"
        echo "   Current configuration will be preserved."
        echo "   To use this statusline, update settings.json manually:"
        echo "   \"statusLine\": {"
        echo "     \"type\": \"command\","
        echo "     \"command\": \"bash ~/.claude/statusline-command.sh\""
        echo "   }"
    else
        # Add statusLine configuration
        # Create a temporary file with updated settings
        jq '.statusLine = {"type": "command", "command": "bash ~/.claude/statusline-command.sh"}' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
        mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
        echo "✓ Updated settings.json with statusLine configuration"
    fi
else
    echo "⚠️  settings.json not found at ${SETTINGS_FILE}"
    echo "   Creating new settings file..."
    cat > "$SETTINGS_FILE" << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
EOF
    echo "✓ Created new settings.json"
fi

echo ""
echo "✨ Installation complete!"
echo ""
echo "Your statusline is now active! It will show:"
echo "  Line 1: Directory, model, account type"
echo "  Line 2: Git branch and status (with colors!)"
echo "  Line 3: Context %, session info, costs, time"
echo ""
echo "To customize your account type, edit:"
echo "  ${ACCOUNT_CONFIG}"
echo ""
echo "Enjoy your enhanced Claude Code experience! 🎉"
