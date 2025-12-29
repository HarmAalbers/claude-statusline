#!/usr/bin/env bash
# Deploy statusline from development to production

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROD_DIR="$HOME/.claude/statusline-repo"
DEV_DIR="$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Statusline Deployment Script${NC}"
echo "=================================="
echo ""

# Check if we're in a git repo with no uncommitted changes
cd "$DEV_DIR"
if [[ -n $(git status --porcelain) ]]; then
    echo -e "${RED}❌ Error: You have uncommitted changes in development repo${NC}"
    echo "Please commit or stash your changes before deploying."
    git status --short
    exit 1
fi

# Check if production directory exists
if [[ ! -d "$PROD_DIR" ]]; then
    echo -e "${RED}❌ Error: Production directory not found at $PROD_DIR${NC}"
    exit 1
fi

# Show what we're deploying
echo -e "${YELLOW}Development repo:${NC} $DEV_DIR"
echo -e "${YELLOW}Production repo:${NC}  $PROD_DIR"
echo ""

# Get current commit info
CURRENT_COMMIT=$(git rev-parse --short HEAD)
CURRENT_MSG=$(git log -1 --pretty=format:"%s")
echo -e "${YELLOW}Deploying commit:${NC} $CURRENT_COMMIT - $CURRENT_MSG"
echo ""

# Check if this commit is pushed to GitHub
if ! git branch -r --contains "$CURRENT_COMMIT" | grep -q "origin/main"; then
    echo -e "${YELLOW}⚠️  Warning: Current commit is not pushed to GitHub${NC}"
    read -p "Push to GitHub first? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Pushing to GitHub..."
        git push origin main
        echo -e "${GREEN}✅ Pushed to GitHub${NC}"
        echo ""
    fi
fi

# Ask for confirmation
read -p "Deploy to production? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Deploy by pulling in production repo
echo ""
echo -e "${YELLOW}Deploying...${NC}"
cd "$PROD_DIR"

# Fetch latest
git fetch origin

# Check if production has uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    echo -e "${RED}❌ Error: Production repo has uncommitted changes${NC}"
    git status --short
    exit 1
fi

# Pull from origin
echo "Pulling from GitHub into production..."
git pull origin main

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""

# Show what changed
echo -e "${YELLOW}Production is now at:${NC}"
git log -1 --oneline --decorate
echo ""
echo -e "${YELLOW}📊 Changes deployed:${NC}"
git diff HEAD@{1} HEAD --stat

echo ""
echo -e "${GREEN}🎉 Statusline updated successfully!${NC}"
echo "Claude Code will use the new version immediately."
