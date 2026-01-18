#!/bin/bash
#
# Build the Claude Copy URL handler app
#
# This script compiles the AppleScript into a macOS app bundle
# and configures it to handle claude-copy:// URLs.
#
# Usage: ./build-handler.sh
# Output: claude-copy.app in the current directory

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HANDLERS_DIR="${SCRIPT_DIR}/handlers"
OUTPUT_APP="${SCRIPT_DIR}/claude-copy.app"

echo "Building Claude Copy URL handler..."

# Validate source files exist
if [ ! -f "${HANDLERS_DIR}/claude-copy.applescript" ]; then
    echo "Error: handlers/claude-copy.applescript not found" >&2
    exit 1
fi

if [ ! -f "${HANDLERS_DIR}/Info.plist" ]; then
    echo "Error: handlers/Info.plist not found" >&2
    exit 1
fi

# Remove existing app if present
if [ -d "$OUTPUT_APP" ]; then
    echo "Removing existing app..."
    rm -rf "$OUTPUT_APP"
fi

# Compile AppleScript to app bundle
echo "Compiling AppleScript..."
osacompile -o "$OUTPUT_APP" "${HANDLERS_DIR}/claude-copy.applescript"

# Replace the auto-generated Info.plist with our custom one
# that includes URL scheme registration
echo "Installing custom Info.plist..."
cp "${HANDLERS_DIR}/Info.plist" "${OUTPUT_APP}/Contents/Info.plist"

# Touch the app to update modification time (helps with URL registration)
touch "$OUTPUT_APP"

echo ""
echo "Build complete: ${OUTPUT_APP}"
echo ""
echo "To install and register the URL handler:"
echo "  1. Run ./install.sh (recommended)"
echo "  or"
echo "  2. Copy to ~/Applications and open once to register:"
echo "     cp -R claude-copy.app ~/Applications/"
echo "     open ~/Applications/claude-copy.app"
echo ""
echo "Test with:"
echo "  open \"claude-copy://session/\$(echo -n 'test-session-id' | base64)\""
