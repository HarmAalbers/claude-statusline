#!/bin/bash
# Force POSIX locale for consistent number formatting
export LC_NUMERIC=C
export LC_ALL=C

input=$(cat)

# Extract core data from JSON
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd')
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
SESSION_ID=$(echo "$input" | jq -r '.session_id' | cut -c1-8)
TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path')

# Context window data
TOTAL_INPUT=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
TOTAL_OUTPUT=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 1000000')

# Format cost to 2 decimal places (fix floating point precision)
COST=$(printf "%.2f" "$COST" 2>/dev/null || echo "0.00")

# === INPUT/OUTPUT COST BREAKDOWN ===
# Determine pricing based on model (prices per million tokens)
MODEL_ID=$(echo "$input" | jq -r '.model.id // ""')
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

# Calculate input/output costs
INPUT_COST=$(awk "BEGIN {printf \"%.3f\", ($TOTAL_INPUT / 1000000.0 * $INPUT_PRICE)}")
OUTPUT_COST=$(awk "BEGIN {printf \"%.3f\", ($TOTAL_OUTPUT / 1000000.0 * $OUTPUT_PRICE)}")

# Extract session slug
SESSION_SLUG=""
if [ -f "$TRANSCRIPT_PATH" ]; then
    SESSION_SLUG=$(grep -m 1 '"slug"' "$TRANSCRIPT_PATH" 2>/dev/null | jq -r '.slug // empty' 2>/dev/null)
fi

# Check if thinking is enabled
SETTINGS_FILE="${HOME}/.claude/settings.json"
THINKING="false"
if [ -f "$SETTINGS_FILE" ]; then
    THINKING=$(jq -r '.alwaysThinkingEnabled // false' "$SETTINGS_FILE" 2>/dev/null)
fi

# Cache directory
CACHE_DIR="${HOME}/.claude/cache"
mkdir -p "$CACHE_DIR"

# === FIX: Per-session duration tracking ===
SESSION_START_FILE="${CACHE_DIR}/session_start_${SESSION_ID}.txt"
if [ ! -f "$SESSION_START_FILE" ]; then
    date +%s > "$SESSION_START_FILE"
fi
SESSION_START=$(cat "$SESSION_START_FILE" 2>/dev/null || date +%s)
SESSION_DURATION=$(($(date +%s) - SESSION_START))
SESSION_HOURS=$((SESSION_DURATION / 3600))
SESSION_MINS=$(((SESSION_DURATION % 3600) / 60))

# Format session duration
if [ "$SESSION_HOURS" -gt 0 ]; then
    SESSION_TIME="${SESSION_HOURS}h${SESSION_MINS}m"
else
    SESSION_TIME="${SESSION_MINS}m"
fi

# === FIX: Daily cost calculation ===
DAILY_COST_FILE="${CACHE_DIR}/daily_cost_$(date +%Y-%m-%d).txt"
DAILY_SESSIONS_FILE="${CACHE_DIR}/daily_sessions_$(date +%Y-%m-%d).txt"

# Read existing daily cost
if [ -f "$DAILY_COST_FILE" ]; then
    DAILY_COST=$(cat "$DAILY_COST_FILE")
else
    DAILY_COST="0"
fi

# Track session costs in daily file
if [ -f "$DAILY_SESSIONS_FILE" ]; then
    # Update this session's cost
    grep -v "^${SESSION_ID}:" "$DAILY_SESSIONS_FILE" > "${DAILY_SESSIONS_FILE}.tmp" 2>/dev/null || true
    echo "${SESSION_ID}:${COST}" >> "${DAILY_SESSIONS_FILE}.tmp"
    mv "${DAILY_SESSIONS_FILE}.tmp" "$DAILY_SESSIONS_FILE"
else
    echo "${SESSION_ID}:${COST}" > "$DAILY_SESSIONS_FILE"
fi

# Calculate total daily cost from all sessions
DAILY_COST=$(awk -F: '{sum+=$2} END {printf "%.2f", sum}' "$DAILY_SESSIONS_FILE" 2>/dev/null || echo "0.00")
echo "$DAILY_COST" > "$DAILY_COST_FILE"

# Hourly burn rate (use session duration if > 0)
if [ "$SESSION_DURATION" -gt 60 ]; then
    HOURLY_RATE=$(awk "BEGIN {printf \"%.2f\", ($COST * 3600 / $SESSION_DURATION)}")
else
    HOURLY_RATE="0.00"
fi

# Current time
CURRENT_TIME=$(date +"%H:%M")

# === Git information ===
BRANCH=""
SIZE_LABEL=""
GIT_STATUS=""
GIT_DETAILS=""
if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)

    # Handle detached HEAD
    if [ -z "$BRANCH" ]; then
        BRANCH="detached@$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)"
    fi

    # Detect the default branch
    DEFAULT_BRANCH=$(git -C "$DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [ -z "$DEFAULT_BRANCH" ]; then
        for branch_name in main master develop; do
            if git -C "$DIR" rev-parse --verify "$branch_name" >/dev/null 2>&1; then
                DEFAULT_BRANCH="$branch_name"
                break
            fi
        done
    fi

    # === ENHANCED GIT STATUS - Clear and Prominent ===
    UNTRACKED=$(git -C "$DIR" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    MODIFIED=$(git -C "$DIR" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    STAGED=$(git -C "$DIR" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    STASHED=$(git -C "$DIR" stash list 2>/dev/null | wc -l | tr -d ' ')
    CONFLICTS=$(git -C "$DIR" diff --name-only --diff-filter=U 2>/dev/null | wc -l | tr -d ' ')

    # Build clear, labeled git status with bright colors
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

    # Clean state indicator
    if [ "$STAGED" -eq 0 ] && [ "$MODIFIED" -eq 0 ] && [ "$UNTRACKED" -eq 0 ] && [ "$CONFLICTS" -eq 0 ]; then
        GIT_DETAILS=" \033[1;32m✓Clean\033[0m"
    fi

    GIT_STATUS="${GIT_DETAILS}"

    # Ahead/behind indicators (bright colors)
    AHEAD=$(git -C "$DIR" rev-list --count @{upstream}..HEAD 2>/dev/null)
    if [[ -n "$AHEAD" && "$AHEAD" -gt 0 ]]; then
        GIT_STATUS="${GIT_STATUS} \033[1;94m↑Push:${AHEAD}\033[0m"
    fi

    BEHIND=$(git -C "$DIR" rev-list --count HEAD..@{upstream} 2>/dev/null)
    if [[ -n "$BEHIND" && "$BEHIND" -gt 0 ]]; then
        GIT_STATUS="${GIT_STATUS} \033[1;94m↓Pull:${BEHIND}\033[0m"
    fi

    # PR size label (compact)
    if [ -n "$DEFAULT_BRANCH" ] && [ "$BRANCH" != "$DEFAULT_BRANCH" ]; then
        CHANGES=$(git -C "$DIR" diff --stat "$DEFAULT_BRANCH"...HEAD 2>/dev/null | tail -1 | awk '{print $4+$6}')
        if [ -z "$CHANGES" ]; then
            CHANGES=0
        fi

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

# Display directory relative to home
DIR_DISPLAY="${DIR/#$HOME/~}"

# Model name (shorten for compactness)
MODEL_SHORT=$(echo "$MODEL" | sed 's/Claude //' | sed 's/ Sonnet//' | sed 's/Opus /O/' | sed 's/Haiku /H/')

# === ACCOUNT TYPE DETECTION ===
ACCOUNT_TYPE=""
ACCOUNT_CONFIG="${HOME}/.claude/statusline-account.txt"

# Check if using API key
if [ -n "$ANTHROPIC_API_KEY" ]; then
    ACCOUNT_TYPE="\033[1;33mAPI\033[0m"  # Yellow for API
elif [ -f "$ACCOUNT_CONFIG" ]; then
    # Read from config file
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
    # Default - create config file with placeholder
    echo "Max" > "$ACCOUNT_CONFIG"
    ACCOUNT_TYPE="\033[1;35mMax\033[0m"
fi

# Thinking indicator
THINKING_INDICATOR=""
if [ "$THINKING" = "true" ]; then
    THINKING_INDICATOR=" 🧠"
fi

# Detect language/environment (compact version)
LANG_VERSION=""
if [ -f "$DIR/.python-version" ]; then
    PY_VER=$(cat "$DIR/.python-version" 2>/dev/null | head -1 | cut -d. -f1,2)
    LANG_VERSION=" 🐍${PY_VER}"
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

# Virtual environment (compact)
VENV_INFO=""
if [[ -n "$VIRTUAL_ENV" ]]; then
    VENV_NAME=$(basename "$VIRTUAL_ENV")
    # Abbreviate common venv names
    VENV_NAME=$(echo "$VENV_NAME" | sed 's/venv/v/' | sed 's/virtualenv/v/' | sed 's/.venv/v/')
    VENV_INFO=" (${VENV_NAME})"
fi

# === HACKER ELITE: Context Window Progress Bar ===
TOTAL_TOKENS=$((TOTAL_INPUT + TOTAL_OUTPUT))
CONTEXT_PCT=$(awk "BEGIN {printf \"%.0f\", ($TOTAL_TOKENS * 100 / $CONTEXT_SIZE)}")

# Build progress bar (10 blocks)
FILLED=$((CONTEXT_PCT / 10))
EMPTY=$((10 - FILLED))

# Color code based on usage
if [ "$CONTEXT_PCT" -lt 50 ]; then
    BAR_COLOR="\033[1;32m"  # Green
elif [ "$CONTEXT_PCT" -lt 80 ]; then
    BAR_COLOR="\033[1;33m"  # Yellow
else
    BAR_COLOR="\033[1;31m"  # Red
fi

PROGRESS_BAR="${BAR_COLOR}"
for ((i=0; i<FILLED; i++)); do
    PROGRESS_BAR="${PROGRESS_BAR}▓"
done
PROGRESS_BAR="${PROGRESS_BAR}\033[0;90m"
for ((i=0; i<EMPTY; i++)); do
    PROGRESS_BAR="${PROGRESS_BAR}░"
done
PROGRESS_BAR="${PROGRESS_BAR}\033[0m ${CONTEXT_PCT}%"

# Build session info (show both ID and slug)
SESSION_INFO="📋 ${SESSION_ID}"
if [ -n "$SESSION_SLUG" ]; then
    SESSION_INFO="${SESSION_INFO} (${SESSION_SLUG})"
fi

# === HACKER ELITE: 3-Line Clear Layout ===
LINE1="📁 ${DIR_DISPLAY}${LANG_VERSION}${VENV_INFO} │ \033[0;35m[${MODEL_SHORT}]${THINKING_INDICATOR}\033[0m │ ${ACCOUNT_TYPE}"
LINE2="🌿 \033[1;36m${BRANCH}\033[0m${GIT_STATUS}${SIZE_LABEL}"
LINE3="⚡️ ${PROGRESS_BAR} │ ${SESSION_INFO} │ 💰 \$${COST} (\033[1;32m↓\$${INPUT_COST}\033[0m/\033[1;33m↑\$${OUTPUT_COST}\033[0m) │ 📊 \$${DAILY_COST}/day │ 🔥 \$${HOURLY_RATE}/hr │ ⏱️  ${SESSION_TIME} │ 🕐 ${CURRENT_TIME}"

echo -e "$LINE1"
echo -e "$LINE2"
echo -e "$LINE3"
