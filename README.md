# Claude Code Hacker Elite Statusline 🚀

A beautiful, information-rich statusline for Claude Code with context window tracking, enhanced git status, session management, and cost monitoring.

## Features

### 🎯 Core Features
- **Context Window Progress Bar** - Visual indicator (0-100%) with color-coded warnings
  - 🟢 Green (0-49%): Safe
  - 🟡 Yellow (50-79%): Warning
  - 🔴 Red (80%+): Critical
- **Enhanced Git Status** - Clear, labeled indicators instead of cryptic symbols
  - Conflicts, staged, modified, untracked files
  - Push/pull indicators
  - PR size labels (XS, S, M, L, XL, XXL)
- **Session Tracking** - Session ID and human-readable slug
- **Cost Monitoring** - Session cost, daily total, hourly burn rate
- **Account Type Display** - Shows Pro/Max/Team/API
- **Smart Environment Detection** - Python, Node.js, Go versions
- **Session Duration** - Per-session time tracking

### 🎨 Display Layout

```
Line 1: 📁 Directory 🐍Python │ [Model] │ Max
Line 2: 🌿 branch-name ✓Staged:2 ●Modified:5 ?Untracked:1 ↑Push:3 M
Line 3: ⚡️ ▓▓▓░░░░░░░ 35% │ 📋 session │ 💰 $2.50 │ 📊 $15.20/day │ 🔥 $12.50/hr │ ⏱️ 12m │ 🕐 14:23
```

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
echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"/test"},"cost":{"total_cost_usd":"0"},"context_window":{"total_input_tokens":0,"total_output_tokens":0,"context_window_size":1000000}}' | bash ~/.claude/statusline-command.sh
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
