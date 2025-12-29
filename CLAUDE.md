# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude-statusline is a sophisticated three-line status display for Claude Code that provides real-time context window tracking, git status, session monitoring, and cost tracking. It's a pure Bash implementation with no build system - changes are deployed directly via git.

**Key architecture pattern**: This project uses a **dual-repo development workflow**:
- **Development repo** (`~/Tools/claude-statusline/`) - Where you make changes
- **Production repo** (`~/.claude/statusline-repo/`) - Where Claude Code runs from
- Changes flow: Dev → GitHub → Production (via `deploy.sh`)

## Development Commands

### Testing
```bash
# Manual test of statusline output (check for errors/formatting)
bash statusline.sh

# Test with example JSON input
echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"/test"},"cost":{"total_cost_usd":"0"},"context_window":{"total_input_tokens":0,"total_output_tokens":0,"context_window_size":1000000}}' | bash statusline.sh

# Test in Claude Code without deploying (temporary symlink swap)
ln -sf ~/Tools/claude-statusline/statusline.sh ~/.claude/statusline-command.sh
# ... test in Claude Code ...
# Restore production
ln -sf ~/.claude/statusline-repo/statusline.sh ~/.claude/statusline-command.sh
```

### Deployment
```bash
# Deploy changes to production (recommended workflow)
./deploy.sh

# What deploy.sh does:
# 1. Checks for uncommitted changes in dev repo
# 2. Verifies commit is pushed to GitHub
# 3. Asks for confirmation
# 4. Pulls from GitHub into production repo
# 5. Shows what changed

# Manual deployment (if deploy.sh fails)
cd ~/.claude/statusline-repo
git pull origin main
```

### Git Workflow
```bash
# Standard development cycle
git commit -am "feat: description"
git push origin main
./deploy.sh

# Emergency rollback production
cd ~/.claude/statusline-repo
git log --oneline  # find last good commit
git reset --hard <good-commit-hash>
```

## Code Architecture

### Single Script Design
The entire statusline is implemented in `statusline.sh` (~576 lines) as a single executable with no external dependencies beyond `jq` and standard bash utilities.

### Input/Output Contract
- **Input**: JSON via stdin from Claude Code with workspace, cost, model, session, and context window data
- **Output**: Three formatted lines to stdout
  - Line 1: Directory, language/environment, model, account type
  - Line 2: Git status (branch, changes, PR info)
  - Line 3: Context bar, session info, costs, duration, time

### Major Functional Sections

1. **Input Validation** (lines 20-110): Type-safe extraction and validation of all JSON inputs to prevent injection attacks
2. **Cost Breakdown** (lines 114-146): Model-specific pricing with input/output cost separation
3. **Session Tracking** (lines 172-256): Per-session timestamps and daily cost aggregation using atomic file updates in `~/.claude/cache/`
4. **Git Integration** (lines 259-424): Branch detection, GitHub PR/branch link generation, change counting, upstream tracking
5. **Display Formatting** (lines 428-576): Environment detection, progress bar rendering, three-line output generation

### State Management
Session and cost tracking uses filesystem-based state in `~/.claude/cache/`:
- `session_start_<SESSION_ID>.txt` - Session start timestamp
- `daily_cost_<YYYY-MM-DD>.txt` - Daily total cost
- `daily_sessions_<YYYY-MM-DD>.txt` - Per-session cost breakdown

All file updates are atomic to prevent corruption from concurrent Claude Code instances.

### GitHub Integration
The statusline detects PRs and generates GitHub links using the `gh` CLI. It supports per-repo GitHub authentication via:
```bash
# Per-repo config (takes precedence)
git config statusline.ghConfigDir ~/.config/gh-work

# Environment variable (ad-hoc override)
STATUSLINE_GH_CONFIG_DIR=~/.config/gh-personal
```

## Critical Patterns

### Locale Forcing
All numeric operations require C locale to prevent decimal separator issues:
```bash
export LC_NUMERIC=C
export LC_ALL=C
```

### Single jq Call Pattern
Performance optimization: Extract all JSON fields in one `jq` invocation rather than spawning 9 separate processes:
```bash
IFS=$'\t' read -r DIR COST MODEL ... < <(
    echo "$input" | jq -r '[.field1, .field2, ...] | @tsv'
)
```

### Division by Zero Prevention
Context window size validation ensures no division by zero in percentage calculations (defaults to 1000000 if zero/invalid).

### Git Operations Safety
All git commands include error handling and fallbacks. The script gracefully degrades when not in a git repository or when git features are unavailable.

## Dependencies

**Required**:
- `jq` - JSON parsing (install: `brew install jq`)
- `bash` - Standard shell

**Optional**:
- `git` - For git status features
- `gh` - For GitHub PR/branch link generation

## Installation Flow

The `install.sh` script:
1. Copies `statusline.sh` to `~/.claude/statusline-command.sh`
2. Updates `~/.claude/settings.json` to configure Claude Code's statusLine setting
3. Creates `~/.claude/statusline-account.txt` with account type (Pro/Max/Team)
4. Sets executable permissions

## Testing Philosophy

This project relies on manual testing rather than automated tests:
- Run script manually and inspect output
- Test with real Claude Code sessions
- Use symlink swapping for safe testing of changes before deployment
- Verify production deployment during low-stakes time

## Key Constraints

1. **No breaking changes to JSON contract**: Claude Code provides the input format - we must adapt to it
2. **Single script constraint**: Entire implementation must remain in one executable file for easy deployment
3. **Performance**: Minimize process spawning (jq, git, gh calls) as script runs on every statusline refresh
4. **Safety**: All inputs must be validated - assume malicious JSON input
5. **Atomicity**: Session state updates must be atomic to handle concurrent Claude Code instances
