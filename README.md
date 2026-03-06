# Claude Code Hacker Elite Statusline 🚀

A beautiful, information-rich statusline for Claude Code with context window tracking, enhanced git status, session management, and cost monitoring.

## Features

### 🎯 Core Features
- **Context Window Progress Bar** - Visual indicator (0-100%) with color-coded warnings
  - 🟢 Green (0-49%): Safe
  - 🟡 Yellow (50-79%): Warning
  - 🔴 Red (80%+): Critical
- **Cache Efficiency Indicator** - Shows prompt cache hit rate (⚡️XX%)
  - 🟢 Green (>60%): Excellent cache reuse
  - 🟡 Yellow (30-60%): Moderate reuse
  - ⚪ Dim (<30%): Low cache utilization
- **API Latency Display** - Shows API response time (📡X.Xs)
  - Helps identify network vs processing bottlenecks
- **Code Churn Metrics** - Lines added/removed in session (📝 +N/-M)
  - See the impact of your changes at a glance
- **Long-Context Pricing** - Accurate cost when exceeds 200K tokens (2x input, 1.5x output)
  - Context size label (e.g., "1M") shown in red when long-context pricing is active
- **Vim Mode Indicator** - Shows `[N]` (blue) for NORMAL, `[I]` (green) for INSERT
- **Output Style Display** - Shows current style when non-default (e.g., `(explanatory)`)
- **Agent Name Display** - Shows active agent with robot emoji when using `--agent`
- **Worktree Indicator** - Shows active git worktree name on the git status line
- **Navigation Indicator** - Shows `(from ~/project)` when current dir diverges from project root
- **Claude Code Version** - Shows the CLI version (vX.X.X)
- **Enhanced Git Status** - Clear, labeled indicators instead of cryptic symbols
  - Conflicts, staged, modified, untracked files
  - Push/pull indicators
  - PR size labels (XS, S, M, L, XL, XXL)
- **Session Tracking** - Session ID and human-readable slug
- **Cost Monitoring** - Session cost, daily total, hourly burn rate
  - Input/output cost breakdown (↓input/↑output)
- **Account Type Display** - Shows Pro/Max/Team/API
- **Smart Environment Detection** - Python, Node.js, Go versions
- **Session Duration** - Per-session time tracking

### 🎨 Display Layout

```
Line 1: 📁 ~/project (from ~/root) 🐍Python │ [Model]🧠[N] 🤖agent v2.1.69 │ Max (explanatory)
Line 2: 🌳worktree 🌿 branch-name [PR #42] ✓Staged:2 ●Modified:5 ?Untracked:1 ↑Push:3 M
Line 3: ⚡️ ▓▓▓░░░░░░░ 35% 1M ⚡75% 📡2.3s │ 📋 session │ 📝 +156/-23 │ 💰 $2.50 (↓$0.12/↑$1.23) │ 📊 $15.20/day │ 🔥 $12.50/hr │ ⏱️ 12m │ 🕐 14:23
```

**Layout breakdown:**
- **Line 1**: Directory, nav indicator, language/env, model, thinking, vim mode, agent, version, account type, output style
- **Line 2**: Worktree, git branch, GitHub PR link, file status, push/pull counts, PR size
- **Line 3**: Context bar, context size label, cache efficiency, API latency, session info, code churn, costs, time

## Installation

### Quick Install (Recommended)

```bash
cd ~/.claude/statusline-repo
./install.sh
```

The installer will:
- Copy the statusline script to `~/.claude/statusline-command.sh`
- Update your `~/.claude/settings.json` to use the statusline
- Create account configuration file
- Set proper permissions

### Manual Install

1. Copy the statusline script:
```bash
cp statusline.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

2. Update your `~/.claude/settings.json`:
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

3. Set your account type:
```bash
echo "Max" > ~/.claude/statusline-account.txt
```

## Configuration

### Account Type

Edit `~/.claude/statusline-account.txt` to set your subscription plan:

```bash
echo "Pro" > ~/.claude/statusline-account.txt   # For Pro plan
echo "Max" > ~/.claude/statusline-account.txt   # For Max plan
echo "Team" > ~/.claude/statusline-account.txt  # For Team plan
```

If you use the Anthropic API with `ANTHROPIC_API_KEY`, it will automatically show "API" in yellow.

### Customization

The statusline script uses standard bash and supports customization:

- **Colors**: Edit the ANSI color codes in the script
- **Layout**: Modify LINE1, LINE2, LINE3 variables
- **Metrics**: Add/remove information as needed

## Git Status Indicators

| Indicator | Meaning | Color |
|-----------|---------|-------|
| ⚠️CONFLICT:N | Merge conflicts | Bright Red |
| ✓Staged:N | Files ready to commit | Bright Green |
| ●Modified:N | Changed files | Bright Yellow |
| ?Untracked:N | New files | Bright Cyan |
| ✦Stash:N | Stashed changes | Magenta |
| ✓Clean | No changes | Bright Green |
| ↑Push:N | Commits to push | Blue |
| ↓Pull:N | Commits to pull | Blue |

### Using different GitHub accounts per project

If you collaborate with multiple GitHub accounts, point the statusline's `gh` calls
at a custom config directory. Each project can keep its own `gh` credentials:

```bash
# set once per repo
git config statusline.ghConfigDir ~/.config/gh-work

# or use an environment override for ad-hoc runs
STATUSLINE_GH_CONFIG_DIR=~/.config/gh-personal bash ~/.claude/statusline-command.sh
```

The git config value takes precedence over the environment variable. Both options
are compatible with the GitHub CLI's multiple-config support.

## Performance Indicators

### Cache Efficiency (⚡️XX%)

Shows the ratio of cache reads to cache writes. Higher percentages mean Claude is reusing cached context effectively, reducing costs.

| Range | Color | Meaning |
|-------|-------|---------|
| >60% | Green | Excellent - High cache reuse |
| 30-60% | Yellow | Moderate - Some cache utilization |
| <30% | Dim | Low - Mostly new context |

### API Latency (📡X.Xs)

Shows the total API response time during the session. Helps identify if slowdowns are due to network/API latency or local processing.

### Code Churn (📝 +N/-M)

Shows lines added and removed during this session, with the net change in parentheses. Useful for tracking the impact of your changes.

## PR Size Labels

Based on lines changed from default branch:

- **XS**: ≤10 lines (Green)
- **S**: 11-30 lines (Green)
- **M**: 31-100 lines (Yellow)
- **L**: 101-500 lines (Yellow)
- **XL**: 501-1000 lines (Red)
- **XXL**: 1000+ lines (Red)

## Requirements

- Claude Code CLI (obviously! 😄)
- `jq` - JSON processor (install with: `brew install jq` on macOS)
- `bash` - Standard shell
- `git` - For git status features

## Troubleshooting

### Statusline not showing

1. Check if script is executable:
```bash
chmod +x ~/.claude/statusline-command.sh
```

2. Test the script manually:
```bash
echo '{"version":"1.0.80","model":{"display_name":"Test","id":"claude-sonnet-4"},"workspace":{"current_dir":"/test"},"cost":{"total_cost_usd":"1.25","total_lines_added":50,"total_lines_removed":10,"total_duration_ms":30000,"total_api_duration_ms":15000},"context_window":{"total_input_tokens":5000,"total_output_tokens":1000,"context_window_size":200000,"used_percentage":35,"current_usage":{"cache_read_input_tokens":3000,"cache_creation_input_tokens":1000}}}' | bash ~/.claude/statusline-command.sh
```

### Numbers not formatting correctly

The script forces C locale for consistent number formatting. If you see issues, ensure `LC_ALL=C` is working in your environment.

### Git status not showing

Make sure you're in a git repository. The git status features only activate when inside a repo.

## Contributing

Found a bug? Have an improvement? Feel free to:
1. Fork the repository
2. Make your changes
3. Submit a pull request

## License

MIT License - Feel free to use, modify, and share!

## Credits

Created for the Claude Code community. Built with insights from:
- [Claude Code Documentation](https://code.claude.com/docs/en/statusline)
- Community feedback and testing
- Hacker elite styling inspired by powerline and other terminal tools

---

**Enjoy your enhanced Claude Code experience!** 🎉
