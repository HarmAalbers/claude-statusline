#!/bin/bash
# Claude Code Hacker Elite Statusline
#
# A production-ready statusline for Claude Code with context window tracking,
# enhanced git status, session management, and cost monitoring.
#
# Dependencies: jq (required), git (optional for git features)
# Input: JSON via stdin from Claude Code
# Output: 3-line formatted statusline to stdout

# Force POSIX locale for consistent number formatting
# This prevents locale-specific decimal separators (e.g., comma vs period)
# from breaking the awk calculations used throughout this script
export LC_NUMERIC=C
export LC_ALL=C

# ============================================================================
# INPUT VALIDATION FUNCTIONS
# ============================================================================

# Validate that a value is numeric (integer or float)
validate_number() {
    local val="$1"
    local default="${2:-0}"
    if [[ "$val" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "$val"
    else
        echo "$default"
    fi
}

# Validate that a value is a positive integer
validate_integer() {
    local val="$1"
    local default="${2:-0}"
    if [[ "$val" =~ ^[0-9]+$ ]]; then
        echo "$val"
    else
        echo "$default"
    fi
}

# Validate that a directory path exists and is readable
validate_directory() {
    local dir="$1"
    if [ -d "$dir" ] && [ -r "$dir" ]; then
        echo "$dir"
    else
        echo "."
    fi
}

# ============================================================================
# INPUT EXTRACTION AND VALIDATION
# ============================================================================

# Read JSON input from stdin
input=$(cat)

# Validate we received input
if [ -z "$input" ]; then
    echo "Error: No input received from Claude Code" >&2
    exit 1
fi

# Validate it's valid JSON
if ! echo "$input" | jq empty 2>/dev/null; then
    echo "Error: Input is not valid JSON" >&2
    exit 1
fi

# Extract all data in a single jq call for performance
# This reduces 9 separate process spawns to just 1
# Set IFS to tab-only to correctly parse tab-separated values with spaces
IFS=$'\t' read -r DIR COST MODEL SESSION_ID TRANSCRIPT_PATH \
        TOTAL_INPUT TOTAL_OUTPUT CONTEXT_SIZE MODEL_ID < <(
    echo "$input" | jq -r '[
        .workspace.current_dir,
        (.cost.total_cost_usd // "0"),
        (.model.display_name // "Claude"),
        (.session_id // "unknown"),
        (.transcript_path // ""),
        (.context_window.total_input_tokens // 0),
        (.context_window.total_output_tokens // 0),
        (.context_window.context_window_size // 1000000),
        (.model.id // "")
    ] | @tsv' 2>/dev/null
)

# Validate and sanitize extracted values
DIR=$(validate_directory "$DIR")
COST=$(validate_number "$COST" "0")
SESSION_ID="${SESSION_ID:0:8}"  # Truncate to first 8 chars
TOTAL_INPUT=$(validate_integer "$TOTAL_INPUT" "0")
TOTAL_OUTPUT=$(validate_integer "$TOTAL_OUTPUT" "0")
CONTEXT_SIZE=$(validate_integer "$CONTEXT_SIZE" "1000000")

# Prevent division by zero in context calculations
if [ "$CONTEXT_SIZE" -eq 0 ]; then
    CONTEXT_SIZE=1000000
fi

# Format cost to 2 decimal places with validation
if ! [[ "$COST" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    echo "Warning: Invalid cost value from API: '$COST', defaulting to 0.00" >&2
    COST="0.00"
else
    COST=$(printf "%.2f" "$COST")
fi

# ============================================================================
# INPUT/OUTPUT COST BREAKDOWN
# ============================================================================

# Calculate separate input/output costs based on model pricing
# API pricing per million tokens (as of 2025)
INPUT_PRICE=3    # Default: Sonnet 4.5
OUTPUT_PRICE=15

case "$MODEL_ID" in
    *opus-4*)
        INPUT_PRICE=5
        OUTPUT_PRICE=25
        ;;
    *sonnet-4*)
        INPUT_PRICE=3
        OUTPUT_PRICE=15
        ;;
    *haiku-4*)
        INPUT_PRICE=1
        OUTPUT_PRICE=5
        ;;
    *haiku-3.5*)
        INPUT_PRICE=0.8
        OUTPUT_PRICE=4
        ;;
    *haiku-3*)
        INPUT_PRICE=0.25
        OUTPUT_PRICE=1.25
        ;;
esac

# Calculate costs: (tokens / 1 million) * price_per_million
# Using validated numeric inputs to prevent injection
INPUT_COST=$(awk "BEGIN {printf \"%.3f\", ($TOTAL_INPUT / 1000000.0 * $INPUT_PRICE)}")
OUTPUT_COST=$(awk "BEGIN {printf \"%.3f\", ($TOTAL_OUTPUT / 1000000.0 * $OUTPUT_PRICE)}")

# ============================================================================
# SESSION INFORMATION
# ============================================================================

# Extract session slug from transcript file
# The slug is a human-readable name (e.g., "robust-petting-chipmunk")
SESSION_SLUG=""
if [ -f "$TRANSCRIPT_PATH" ] && [[ "$TRANSCRIPT_PATH" == "$HOME/.claude/"* ]]; then
    SESSION_SLUG=$(grep -m 1 '"slug"' "$TRANSCRIPT_PATH" 2>/dev/null | jq -r '.slug // empty' 2>/dev/null)
fi

# Check if thinking mode is enabled in settings
SETTINGS_FILE="${HOME}/.claude/settings.json"
THINKING="false"
if [ -f "$SETTINGS_FILE" ]; then
    THINKING=$(jq -r '.alwaysThinkingEnabled // false' "$SETTINGS_FILE" 2>/dev/null)
    # Validate output is actually true/false
    if [ "$THINKING" != "true" ] && [ "$THINKING" != "false" ]; then
        THINKING="false"
    fi
fi

# ============================================================================
# SESSION DURATION AND COST TRACKING
# ============================================================================

# Cache directory for session tracking
CACHE_DIR="${HOME}/.claude/cache"
if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
    echo "Warning: Cannot create cache directory, using /tmp fallback" >&2
    CACHE_DIR="/tmp/claude-statusline-$$"
    mkdir -p "$CACHE_DIR" 2>/dev/null || CACHE_DIR="/tmp"
fi

# Per-session duration tracking
# Each session gets its own timestamp file based on session ID
SESSION_START_FILE="${CACHE_DIR}/session_start_${SESSION_ID}.txt"
if [ ! -f "$SESSION_START_FILE" ]; then
    date +%s > "$SESSION_START_FILE" 2>/dev/null
fi

SESSION_START=$(cat "$SESSION_START_FILE" 2>/dev/null)
# Validate SESSION_START is a valid timestamp
if ! [[ "$SESSION_START" =~ ^[0-9]+$ ]]; then
    SESSION_START=$(date +%s)
    echo "$SESSION_START" > "$SESSION_START_FILE" 2>/dev/null
fi

SESSION_DURATION=$(($(date +%s) - SESSION_START))
SESSION_HOURS=$((SESSION_DURATION / 3600))
SESSION_MINS=$(((SESSION_DURATION % 3600) / 60))

# Format session duration (show hours only if > 0)
if [ "$SESSION_HOURS" -gt 0 ]; then
    SESSION_TIME="${SESSION_HOURS}h${SESSION_MINS}m"
else
    SESSION_TIME="${SESSION_MINS}m"
fi

# Daily cost aggregation across all sessions
DAILY_COST_FILE="${CACHE_DIR}/daily_cost_$(date +%Y-%m-%d).txt"
DAILY_SESSIONS_FILE="${CACHE_DIR}/daily_sessions_$(date +%Y-%m-%d).txt"

# Read existing daily cost or default to 0
if [ -f "$DAILY_COST_FILE" ]; then
    DAILY_COST=$(cat "$DAILY_COST_FILE" 2>/dev/null)
    DAILY_COST=$(validate_number "$DAILY_COST" "0")
else
    DAILY_COST="0"
fi

# Update session cost in daily tracking file
# Format: SESSION_ID:COST (one line per session)
# We remove the current session's old entry and append the updated cost
if [ -f "$DAILY_SESSIONS_FILE" ]; then
    # Use atomic-ish update: create temp file, then move
    if grep -v "^${SESSION_ID}:" "$DAILY_SESSIONS_FILE" 2>/dev/null > "${DAILY_SESSIONS_FILE}.tmp"; then
        echo "${SESSION_ID}:${COST}" >> "${DAILY_SESSIONS_FILE}.tmp"
        mv "${DAILY_SESSIONS_FILE}.tmp" "$DAILY_SESSIONS_FILE" 2>/dev/null || {
            echo "Warning: Failed to update daily sessions file" >&2
            rm -f "${DAILY_SESSIONS_FILE}.tmp"
        }
    else
        # File empty or grep failed - start fresh
        echo "${SESSION_ID}:${COST}" > "$DAILY_SESSIONS_FILE" 2>/dev/null
    fi
else
    echo "${SESSION_ID}:${COST}" > "$DAILY_SESSIONS_FILE" 2>/dev/null
fi

# Calculate total daily cost by summing all session costs
if [ -f "$DAILY_SESSIONS_FILE" ]; then
    DAILY_COST=$(awk -F: '{sum+=$2} END {printf "%.2f", sum}' "$DAILY_SESSIONS_FILE" 2>/dev/null)
    if [ -z "$DAILY_COST" ]; then
        DAILY_COST="0.00"
    fi
    echo "$DAILY_COST" > "$DAILY_COST_FILE" 2>/dev/null
fi

# Calculate hourly burn rate (skip if session < 1 minute to avoid unrealistic rates)
# Hourly rate = (current session cost) * (3600 seconds/hour) / (session duration in seconds)
if [ "$SESSION_DURATION" -gt 60 ]; then
    HOURLY_RATE=$(awk "BEGIN {printf \"%.2f\", ($COST * 3600 / $SESSION_DURATION)}")
else
    HOURLY_RATE="0.00"
fi

# Current time for display
CURRENT_TIME=$(date +"%H:%M")

# ============================================================================
# GIT INFORMATION
# ============================================================================

BRANCH=""
SIZE_LABEL=""
GIT_STATUS=""
GIT_DETAILS=""
GITHUB_LINK=""

# Only process git info if we're in a git repository
if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
    # Get current branch name
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)

    # Handle detached HEAD state (when not on any branch)
    # Show "detached@" followed by short commit hash
    if [ -z "$BRANCH" ]; then
        BRANCH="detached@$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)"
    fi

    # Determine upstream branch and repository URL (GitHub only)
    UPSTREAM_REF=$(git -C "$DIR" rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null)
    UPSTREAM_REMOTE="${UPSTREAM_REF%%/*}"
    UPSTREAM_BRANCH="${UPSTREAM_REF#*/}"
    REMOTE_NAME=${UPSTREAM_REMOTE:-origin}
    REMOTE_URL=$(git -C "$DIR" config --get "remote.${REMOTE_NAME}.url" 2>/dev/null)

    # Normalize GitHub remote URLs to https://github.com/owner/repo form
    REPO_PATH=""
    if [[ "$REMOTE_URL" =~ ^git@github.com:(.*)\.git$ ]]; then
        REPO_PATH="${BASH_REMATCH[1]}"
    elif [[ "$REMOTE_URL" =~ ^git@github.com:(.*)$ ]]; then
        REPO_PATH="${BASH_REMATCH[1]}"
    elif [[ "$REMOTE_URL" =~ ^https?://github.com/(.*)\.git$ ]]; then
        REPO_PATH="${BASH_REMATCH[1]}"
    elif [[ "$REMOTE_URL" =~ ^https?://github.com/(.*)$ ]]; then
        REPO_PATH="${BASH_REMATCH[1]}"
    fi

    # Build GitHub branch/PR link if possible
    if [ -n "$REPO_PATH" ]; then
        REPO_URL="https://github.com/${REPO_PATH}"
        TARGET_BRANCH=${UPSTREAM_BRANCH:-$BRANCH}

        if [ -n "$TARGET_BRANCH" ]; then
            PR_URL=""
            # If GitHub CLI is available, try to fetch PR URL for the branch
            if command -v gh >/dev/null 2>&1; then
                PR_URL=$(gh pr view "$TARGET_BRANCH" --repo "$REPO_PATH" --json url 2>/dev/null | jq -r '.url // empty')
            fi

            BRANCH_URL="${REPO_URL}/tree/${TARGET_BRANCH}"
            LINK_URL="${PR_URL:-$BRANCH_URL}"
            GITHUB_LINK=" (${LINK_URL})"
        fi
    fi

    # Detect the default branch by checking symbolic-ref first,
    # then falling back to common branch names (main, master, develop)
    DEFAULT_BRANCH=$(git -C "$DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [ -z "$DEFAULT_BRANCH" ]; then
        # Fallback: check if common default branches exist locally
        for branch_name in main master develop; do
            if git -C "$DIR" rev-parse --verify "$branch_name" >/dev/null 2>&1; then
                DEFAULT_BRANCH="$branch_name"
                break
            fi
        done
    fi

    # Get file counts for different git statuses
    UNTRACKED=$(git -C "$DIR" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    MODIFIED=$(git -C "$DIR" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    STAGED=$(git -C "$DIR" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    STASHED=$(git -C "$DIR" stash list 2>/dev/null | wc -l | tr -d ' ')
    CONFLICTS=$(git -C "$DIR" diff --name-only --diff-filter=U 2>/dev/null | wc -l | tr -d ' ')

    # Validate all counts are numeric
    UNTRACKED=$(validate_integer "$UNTRACKED" "0")
    MODIFIED=$(validate_integer "$MODIFIED" "0")
    STAGED=$(validate_integer "$STAGED" "0")
    STASHED=$(validate_integer "$STASHED" "0")
    CONFLICTS=$(validate_integer "$CONFLICTS" "0")

    # Build clear, labeled git status with bright colors
    # Priority order: conflicts (most critical) → staged → modified → untracked → stashed
    GIT_DETAILS=""

    # Conflicts (most critical - bright red)
    if [ "$CONFLICTS" -gt 0 ]; then
        GIT_DETAILS="${GIT_DETAILS} \033[1;91m⚠️CONFLICT:${CONFLICTS}\033[0m"
    fi

    # Staged changes (green - ready to commit)
    if [ "$STAGED" -gt 0 ]; then
        GIT_DETAILS="${GIT_DETAILS} \033[1;92m✓Staged:${STAGED}\033[0m"
    fi

    # Modified (bright yellow - needs attention)
    if [ "$MODIFIED" -gt 0 ]; then
        GIT_DETAILS="${GIT_DETAILS} \033[1;93m●Modified:${MODIFIED}\033[0m"
    fi

    # Untracked (cyan - new files)
    if [ "$UNTRACKED" -gt 0 ]; then
        GIT_DETAILS="${GIT_DETAILS} \033[1;96m?Untracked:${UNTRACKED}\033[0m"
    fi

    # Stashed (magenta)
    if [ "$STASHED" -gt 0 ]; then
        GIT_DETAILS="${GIT_DETAILS} \033[1;95m✦Stash:${STASHED}\033[0m"
    fi

    # Clean state indicator (only if no changes)
    if [ "$STAGED" -eq 0 ] && [ "$MODIFIED" -eq 0 ] && [ "$UNTRACKED" -eq 0 ] && [ "$CONFLICTS" -eq 0 ]; then
        GIT_DETAILS=" \033[1;32m✓Clean\033[0m"
    fi

    GIT_STATUS="${GIT_DETAILS}"

    # Ahead/behind indicators (commits to push/pull)
    AHEAD=$(git -C "$DIR" rev-list --count @{upstream}..HEAD 2>/dev/null)
    if [ -n "$AHEAD" ] && [ "$AHEAD" -gt 0 ] 2>/dev/null; then
        GIT_STATUS="${GIT_STATUS} \033[1;94m↑Push:${AHEAD}\033[0m"
    fi

    BEHIND=$(git -C "$DIR" rev-list --count HEAD..@{upstream} 2>/dev/null)
    if [ -n "$BEHIND" ] && [ "$BEHIND" -gt 0 ] 2>/dev/null; then
        GIT_STATUS="${GIT_STATUS} \033[1;94m↓Pull:${BEHIND}\033[0m"
    fi

    # Calculate PR size as total insertions + deletions compared to default branch
    # Uses three-dot diff to compare merge base (common ancestor) with current HEAD
    if [ -n "$DEFAULT_BRANCH" ] && [ "$BRANCH" != "$DEFAULT_BRANCH" ]; then
        CHANGES=$(git -C "$DIR" diff --stat "$DEFAULT_BRANCH"...HEAD 2>/dev/null | tail -1 | awk '{print $4+$6}')
        # Validate CHANGES is numeric
        CHANGES=$(validate_integer "$CHANGES" "0")

        # Color-coded size labels based on lines changed
        if [ "$CHANGES" -le 10 ]; then
            SIZE_LABEL=" \033[1;32mXS\033[0m"
        elif [ "$CHANGES" -le 30 ]; then
            SIZE_LABEL=" \033[1;32mS\033[0m"
        elif [ "$CHANGES" -le 100 ]; then
            SIZE_LABEL=" \033[1;33mM\033[0m"
        elif [ "$CHANGES" -le 500 ]; then
            SIZE_LABEL=" \033[1;33mL\033[0m"
        elif [ "$CHANGES" -le 1000 ]; then
            SIZE_LABEL=" \033[1;31mXL\033[0m"
        else
            SIZE_LABEL=" \033[1;31mXXL\033[0m"
        fi
    fi
fi

# ============================================================================
# DISPLAY FORMATTING
# ============================================================================

# Display directory relative to home
DIR_DISPLAY="${DIR/#$HOME/~}"

# Shorten model name for compact display
MODEL_SHORT=$(echo "$MODEL" | sed -e 's/Claude //' -e 's/ Sonnet//' -e 's/Opus /O/' -e 's/Haiku /H/')

# Thinking indicator
THINKING_INDICATOR=""
if [ "$THINKING" = "true" ]; then
    THINKING_INDICATOR=" 🧠"
fi

# Detect language/environment based on project files
# Priority: .python-version > pyproject.toml/requirements.txt > package.json > go.mod
# Shows version numbers for each detected language/runtime
LANG_VERSION=""
if [ -f "$DIR/.python-version" ]; then
    PY_VER=$(cat "$DIR/.python-version" 2>/dev/null | head -1 | cut -d. -f1,2)
    if [ -n "$PY_VER" ]; then
        LANG_VERSION=" 🐍${PY_VER}"
    fi
elif [ -f "$DIR/pyproject.toml" ] || [ -f "$DIR/requirements.txt" ]; then
    PY_VER=$(python3 --version 2>/dev/null | awk '{print $2}' | cut -d. -f1,2)
    if [ -n "$PY_VER" ]; then
        LANG_VERSION=" 🐍${PY_VER}"
    fi
elif [ -f "$DIR/package.json" ]; then
    NODE_VER=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)
    if [ -n "$NODE_VER" ]; then
        LANG_VERSION=" ⬢${NODE_VER}"
    fi
elif [ -f "$DIR/go.mod" ]; then
    GO_VER=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//' | cut -d. -f1,2)
    if [ -n "$GO_VER" ]; then
        LANG_VERSION=" 🦫${GO_VER}"
    fi
fi

# Virtual environment indicator
# Abbreviates common venv names (.venv, venv, virtualenv → v)
VENV_INFO=""
if [[ -n "$VIRTUAL_ENV" ]]; then
    VENV_NAME=$(basename "$VIRTUAL_ENV")
    # Match .venv before venv to avoid partial matches
    VENV_NAME=$(echo "$VENV_NAME" | sed -e 's/\.venv/v/' -e 's/virtualenv/v/' -e 's/venv/v/')
    VENV_INFO=" (${VENV_NAME})"
fi

# ============================================================================
# ACCOUNT TYPE DETECTION
# ============================================================================

ACCOUNT_TYPE=""
ACCOUNT_CONFIG="${HOME}/.claude/statusline-account.txt"

# Check if using API key (takes precedence)
if [ -n "$ANTHROPIC_API_KEY" ]; then
    ACCOUNT_TYPE="\033[1;33mAPI\033[0m"  # Yellow for API
elif [ -f "$ACCOUNT_CONFIG" ]; then
    # Read plan from config file
    PLAN=$(cat "$ACCOUNT_CONFIG" 2>/dev/null | tr -d '[:space:]')
    case "$PLAN" in
        Pro|pro)
            ACCOUNT_TYPE="\033[1;36mPro\033[0m"  # Cyan for Pro
            ;;
        Max|max)
            ACCOUNT_TYPE="\033[1;35mMax\033[0m"  # Magenta for Max
            ;;
        Team|team)
            ACCOUNT_TYPE="\033[1;32mTeam\033[0m"  # Green for Team
            ;;
        *)
            ACCOUNT_TYPE="\033[1;90m${PLAN}\033[0m"  # Gray for unknown
            ;;
    esac
else
    # No config found - create default with Max plan type
    if echo "Max" > "$ACCOUNT_CONFIG" 2>/dev/null; then
        ACCOUNT_TYPE="\033[1;35mMax\033[0m"
    else
        echo "Warning: Cannot create account config file" >&2
        ACCOUNT_TYPE="\033[1;35mMax\033[0m"
    fi
fi

# ============================================================================
# CONTEXT WINDOW PROGRESS BAR
# ============================================================================

# Calculate context usage percentage
TOTAL_TOKENS=$((TOTAL_INPUT + TOTAL_OUTPUT))
CONTEXT_PCT=$(awk "BEGIN {printf \"%.0f\", ($TOTAL_TOKENS * 100 / $CONTEXT_SIZE)}")

# Validate percentage is in valid range
CONTEXT_PCT=$(validate_integer "$CONTEXT_PCT" "0")
if [ "$CONTEXT_PCT" -gt 100 ]; then
    CONTEXT_PCT=100
fi

# Build 10-character progress bar showing token usage percentage
# Each block represents 10% of the context window
FILLED=$((CONTEXT_PCT / 10))
EMPTY=$((10 - FILLED))

# Color code based on usage: green (0-49%), yellow (50-79%), red (80%+)
if [ "$CONTEXT_PCT" -lt 50 ]; then
    BAR_COLOR="\033[1;32m"  # Green - safe
elif [ "$CONTEXT_PCT" -lt 80 ]; then
    BAR_COLOR="\033[1;33m"  # Yellow - warning
else
    BAR_COLOR="\033[1;31m"  # Red - critical
fi

# Build progress bar: ▓ for filled blocks, ░ for empty blocks
PROGRESS_BAR="${BAR_COLOR}"
for ((i=0; i<FILLED; i++)); do
    PROGRESS_BAR="${PROGRESS_BAR}▓"
done
PROGRESS_BAR="${PROGRESS_BAR}\033[0;90m"
for ((i=0; i<EMPTY; i++)); do
    PROGRESS_BAR="${PROGRESS_BAR}░"
done
PROGRESS_BAR="${PROGRESS_BAR}\033[0m ${CONTEXT_PCT}%"

# Build session info (ID + optional human-readable slug)
SESSION_INFO="📋 ${SESSION_ID}"
if [ -n "$SESSION_SLUG" ]; then
    SESSION_INFO="${SESSION_INFO} (${SESSION_SLUG})"
fi

# ============================================================================
# OUTPUT GENERATION
# ============================================================================

# 3-Line layout for clarity and information density
# Line 1: Directory context (location, language, model, account)
# Line 2: Git status (branch, changes, PR size)
# Line 3: Session metrics (context, costs, time)

LINE1="📁 ${DIR_DISPLAY}${LANG_VERSION}${VENV_INFO} │ \033[0;35m[${MODEL_SHORT}]${THINKING_INDICATOR}\033[0m │ ${ACCOUNT_TYPE}"
LINE2="🌿 \033[1;36m${BRANCH}\033[0m${GITHUB_LINK}${GIT_STATUS}${SIZE_LABEL}"
LINE3="⚡️ ${PROGRESS_BAR} │ ${SESSION_INFO} │ 💰 \$${COST} (\033[1;32m↓\$${INPUT_COST}\033[0m/\033[1;33m↑\$${OUTPUT_COST}\033[0m) │ 📊 \$${DAILY_COST}/day │ 🔥 \$${HOURLY_RATE}/hr │ ⏱️  ${SESSION_TIME} │ 🕐 ${CURRENT_TIME}"

echo -e "$LINE1"
echo -e "$LINE2"
echo -e "$LINE3"
