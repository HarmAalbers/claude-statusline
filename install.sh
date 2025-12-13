#!/bin/bash
#
# Claude Code Hacker Elite Statusline Installer
# Sets up ~/.claude/statusline-command.sh and configures settings.json
# to display enhanced status information with context tracking, git status,
# session management, and cost monitoring.
#
# Usage: ./install.sh
# Requirements: jq (for JSON processing), bash

echo "🚀 Claude Code Hacker Elite Statusline Installer"
echo "================================================="
echo ""

# ============================================================================
# DEPENDENCY CHECKING
# ============================================================================

echo "Checking dependencies..."

# Check for jq (required for JSON processing)
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is not installed"
    echo "   jq is required to parse JSON data from Claude Code API"
    echo "   Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi
echo "✓ jq found"

# Check for git (optional - enables git features)
if ! command -v git &> /dev/null; then
    echo "⚠️  Warning: git not found (git features will be disabled)"
else
    echo "✓ git found"
fi

echo ""

# ============================================================================
# PATH SETUP
# ============================================================================

# Get the directory where this installer script is located
# BASH_SOURCE[0] provides the script path even when sourced or symlinked
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUSLINE_SCRIPT="${SCRIPT_DIR}/statusline.sh"
TARGET_SCRIPT="${HOME}/.claude/statusline-command.sh"
SETTINGS_FILE="${HOME}/.claude/settings.json"
ACCOUNT_CONFIG="${HOME}/.claude/statusline-account.txt"

# Validate that statusline script exists
if [ ! -f "$STATUSLINE_SCRIPT" ]; then
    echo "❌ Error: statusline.sh not found in ${SCRIPT_DIR}"
    echo "   Make sure you're running this installer from the repository directory"
    exit 1
fi

# ============================================================================
# INSTALLATION
# ============================================================================

echo "Installing statusline..."

# Backup existing statusline if it exists
if [ -f "$TARGET_SCRIPT" ]; then
    BACKUP="${TARGET_SCRIPT}.backup.$(date +%Y%m%d-%H%M%S)"
    if ! cp "$TARGET_SCRIPT" "$BACKUP" 2>/dev/null; then
        echo "❌ Error: Failed to backup existing statusline to $BACKUP" >&2
        echo "   Check permissions and disk space" >&2
        exit 1
    fi
    echo "📦 Backed up existing statusline to: ${BACKUP}"
fi

# Copy statusline script to target location
echo "📝 Copying statusline script..."
if ! cp "$STATUSLINE_SCRIPT" "$TARGET_SCRIPT" 2>/dev/null; then
    echo "❌ Error: Failed to copy statusline script to $TARGET_SCRIPT" >&2
    echo "   Check permissions and disk space" >&2
    exit 1
fi

# Make script executable
if ! chmod +x "$TARGET_SCRIPT" 2>/dev/null; then
    echo "❌ Error: Failed to make statusline script executable" >&2
    exit 1
fi

echo "✓ Statusline script installed to ${TARGET_SCRIPT}"

# ============================================================================
# ACCOUNT TYPE CONFIGURATION
# ============================================================================

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

    # Validate input is 1-4
    if [ -n "$choice" ] && ! [[ "$choice" =~ ^[1-4]$ ]]; then
        echo "⚠️  Invalid choice '$choice', using default (Max)"
        choice="2"
    fi

    # Set account type based on choice
    case "$choice" in
        1)
            if ! echo "Pro" > "$ACCOUNT_CONFIG" 2>/dev/null; then
                echo "⚠️  Warning: Could not save account type to $ACCOUNT_CONFIG" >&2
            else
                echo "✓ Set account type to: Pro"
            fi
            ;;
        3)
            if ! echo "Team" > "$ACCOUNT_CONFIG" 2>/dev/null; then
                echo "⚠️  Warning: Could not save account type to $ACCOUNT_CONFIG" >&2
            else
                echo "✓ Set account type to: Team"
            fi
            ;;
        4)
            if ! echo "API" > "$ACCOUNT_CONFIG" 2>/dev/null; then
                echo "⚠️  Warning: Could not save account type to $ACCOUNT_CONFIG" >&2
            else
                echo "✓ Set account type to: API"
            fi
            ;;
        2|*)
            if ! echo "Max" > "$ACCOUNT_CONFIG" 2>/dev/null; then
                echo "⚠️  Warning: Could not save account type to $ACCOUNT_CONFIG" >&2
            else
                echo "✓ Set account type to: Max"
            fi
            ;;
    esac
else
    CURRENT_TYPE=$(tr -d '[:space:]' < "$ACCOUNT_CONFIG" 2>/dev/null)
    echo "✓ Account type already configured: ${CURRENT_TYPE}"
fi

echo ""

# ============================================================================
# SETTINGS.JSON CONFIGURATION
# ============================================================================

echo "Updating Claude Code settings..."

if [ -f "$SETTINGS_FILE" ]; then
    # Check if statusLine is already configured using jq (more robust than grep)
    if jq -e '.statusLine' "$SETTINGS_FILE" >/dev/null 2>&1; then
        CURRENT_CMD=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null)
        echo "⚠️  statusLine already configured in settings.json"
        echo "   Current command: $CURRENT_CMD"
        echo "   Keeping existing configuration."
        echo ""
        echo "   To use this statusline, manually update settings.json:"
        echo "   \"statusLine\": {"
        echo "     \"type\": \"command\","
        echo "     \"command\": \"bash ~/.claude/statusline-command.sh\""
        echo "   }"
    else
        # Add statusLine configuration using jq to preserve existing settings
        # Use temporary file for atomic update to prevent corruption
        if jq '.statusLine = {"type": "command", "command": "bash ~/.claude/statusline-command.sh"}' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" 2>/dev/null; then
            # Validate the tmp file is valid JSON before overwriting
            if jq empty "${SETTINGS_FILE}.tmp" 2>/dev/null; then
                if mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE" 2>/dev/null; then
                    echo "✓ Updated settings.json with statusLine configuration"
                else
                    echo "❌ Error: Failed to move temporary file (mv failed)" >&2
                    rm -f "${SETTINGS_FILE}.tmp"
                    exit 1
                fi
            else
                echo "❌ Error: jq produced invalid JSON, keeping original settings.json" >&2
                rm -f "${SETTINGS_FILE}.tmp"
                exit 1
            fi
        else
            echo "❌ Error: Failed to update settings.json with jq" >&2
            rm -f "${SETTINGS_FILE}.tmp"
            exit 1
        fi
    fi
else
    # Create new settings file if it doesn't exist
    echo "⚠️  settings.json not found at ${SETTINGS_FILE}"
    echo "   Creating new settings file..."

    # Ensure .claude directory exists
    if ! mkdir -p "$(dirname "$SETTINGS_FILE")" 2>/dev/null; then
        echo "❌ Error: Cannot create .claude directory" >&2
        exit 1
    fi

    # Create settings file with statusLine configuration
    if ! cat > "$SETTINGS_FILE" << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
EOF
    then
        echo "❌ Error: Failed to create settings.json at $SETTINGS_FILE" >&2
        echo "   Check that directory exists and you have write permissions" >&2
        exit 1
    fi

    # Validate created file is valid JSON
    if ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
        echo "❌ Error: Created settings.json is not valid JSON" >&2
        rm -f "$SETTINGS_FILE"
        exit 1
    fi

    echo "✓ Created new settings.json"
fi

# ============================================================================
# COMPLETION
# ============================================================================

echo ""
echo "✨ Installation complete!"
echo ""
echo "Your statusline is now active! It will show:"
echo "  Line 1: Directory, model, account type"
echo "  Line 2: Git branch and status (with colors!)"
echo "  Line 3: Context %, session info, costs, time"
echo ""
echo "Features:"
echo "  • Context window progress bar with color warnings"
echo "  • Enhanced git status (conflicts, staged, modified, untracked)"
echo "  • Session tracking (ID + human-readable name)"
echo "  • Cost monitoring (session, daily, hourly rate)"
echo "  • Input/output cost breakdown"
echo "  • Smart environment detection (Python, Node.js, Go)"
echo ""
echo "To customize your account type, edit:"
echo "  ${ACCOUNT_CONFIG}"
echo ""
echo "Enjoy your enhanced Claude Code experience! 🎉"
