# Claude Statusline - Development Workflow

This document explains the dual-repo development pattern for safe statusline development.

## Repository Structure

```
~/Tools/claude-statusline/       ← 🔧 DEVELOPMENT REPO (you are here)
  ├── statusline.sh              Main statusline script
  ├── install.sh                 Installation script
  ├── deploy.sh                  Deployment script (dev → prod)
  ├── README.md                  User documentation
  └── DEVELOPMENT.md             This file

~/.claude/statusline-repo/       ← 🚀 PRODUCTION REPO
  ├── statusline.sh              Active version used by Claude Code
  └── (same structure)

~/.claude/statusline-command.sh  ← Symlink → statusline-repo/statusline.sh
                                   (Claude Code runs this)

GitHub                            ← 📦 SYNC POINT
  github.com/HarmAalbers/claude-statusline
```

## Development Workflow

### 1. Make Changes (Development)

```bash
cd ~/Tools/claude-statusline

# Create a feature branch (optional but recommended)
git checkout -b feat/my-new-feature

# Make your changes
vim statusline.sh

# Test locally if needed (see Testing section below)

# Commit your changes
git add .
git commit -m "feat: add awesome new feature"
```

### 2. Push to GitHub

```bash
# Push your feature branch
git push origin feat/my-new-feature

# Or push directly to main (for small changes)
git checkout main
git merge feat/my-new-feature
git push origin main
```

### 3. Deploy to Production

**Option A: Use deploy script (recommended)**
```bash
cd ~/Tools/claude-statusline
./deploy.sh
```

The deploy script will:
- ✅ Check for uncommitted changes
- ✅ Verify commit is pushed to GitHub
- ✅ Ask for confirmation
- ✅ Pull from GitHub into production
- ✅ Show what changed

**Option B: Manual deployment**
```bash
cd ~/.claude/statusline-repo
git pull origin main
```

That's it! Claude Code will automatically use the updated statusline.

### 4. Verify

Just look at your Claude Code statusline - changes should be active immediately.

## Common Workflows

### Quick Fix

```bash
cd ~/Tools/claude-statusline
# fix something
git commit -am "fix: typo in statusline"
git push origin main
./deploy.sh
```

### Experimental Feature

```bash
cd ~/Tools/claude-statusline
git checkout -b experiment/cool-idea

# develop and test
# if it works:
git checkout main
git merge experiment/cool-idea
git push origin main
./deploy.sh

# if it doesn't work:
git checkout main
git branch -D experiment/cool-idea
# production is unaffected! 🎉
```

### Emergency Rollback

If production is broken:

```bash
cd ~/.claude/statusline-repo
git log --oneline  # find the last good commit
git reset --hard <good-commit-hash>
```

Claude Code will immediately use the reverted version.

## Testing

### Test in Claude Code Without Deploying

You can temporarily point the symlink to your development version:

```bash
# Backup current symlink
ln -sf ~/.claude/statusline-repo/statusline.sh ~/.claude/statusline-command.sh.backup

# Point to dev version
ln -sf ~/Tools/claude-statusline/statusline.sh ~/.claude/statusline-command.sh

# Test in Claude Code
# ... check if it works ...

# Restore production
ln -sf ~/.claude/statusline-repo/statusline.sh ~/.claude/statusline-command.sh
```

### Test Script Manually

```bash
cd ~/Tools/claude-statusline
bash statusline.sh
```

This will output the statusline text - check for errors or formatting issues.

## Best Practices

1. **Always commit before deploying** - Don't deploy uncommitted work
2. **Use feature branches for big changes** - Keep main stable
3. **Test before deploying** - At least run the script manually
4. **Push to GitHub before deploying** - Ensures sync across devices
5. **Deploy during low-stakes time** - Not in the middle of important work

## Troubleshooting

### Production and Development Out of Sync

Check status:
```bash
# Development status
cd ~/Tools/claude-statusline
git status
git log --oneline -5

# Production status
cd ~/.claude/statusline-repo
git status
git log --oneline -5
```

Sync them:
```bash
cd ~/Tools/claude-statusline
git push origin main

cd ~/.claude/statusline-repo
git pull origin main
```

### Deployment Script Doesn't Work

Manual deployment always works:
```bash
cd ~/.claude/statusline-repo
git pull origin main
```

### Want to Develop on Different Machine

Just clone to the same location:
```bash
cd ~/Tools
git clone https://github.com/HarmAalbers/claude-statusline.git
```

## Why This Workflow?

**Safety**: Production stays stable while you experiment
**Flexibility**: Test ideas without breaking your Claude Code
**Sync**: GitHub keeps all your devices in sync
**Rollback**: Easy to revert if something breaks
**History**: Git preserves all your work

## Quick Reference

```bash
# Development cycle
cd ~/Tools/claude-statusline
# ... make changes ...
git commit -am "feat: something"
git push origin main
./deploy.sh

# Emergency rollback
cd ~/.claude/statusline-repo
git reset --hard HEAD@{1}

# Check what's deployed
cd ~/.claude/statusline-repo
git log -1
```

Happy hacking! 🚀
