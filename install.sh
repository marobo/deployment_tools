#!/bin/bash
# install.sh - Install deployment tools on your server
# Usage: curl -sSL https://raw.githubusercontent.com/YOUR_USER/deploy-tools/main/install.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration - UPDATE THIS WITH YOUR REPO URL
REPO_URL="${DEPLOY_TOOLS_REPO:-https://github.com/YOUR_USERNAME/deployment-scripts.git}"
INSTALL_DIR="$HOME/.deploy-tools"
BIN_DIR="/usr/local/bin"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  🛠️  Deploy Tools Installer${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Git is required. Install it first.${NC}"
    exit 1
fi

# Check for docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}⚠️  Docker not found. Make sure it's installed.${NC}"
fi

# Check for jq (needed for DNS API)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq not found. Installing...${NC}"
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq
    elif command -v brew &> /dev/null; then
        brew install jq
    else
        echo -e "${YELLOW}   Please install jq manually for DNS features${NC}"
    fi
fi

# Clone or update repository
if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${GREEN}📥 Updating existing installation...${NC}"
    cd "$INSTALL_DIR"
    git fetch origin
    git reset --hard origin/main
else
    echo -e "${GREEN}📥 Cloning deploy-tools...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Make scripts executable
chmod +x "$INSTALL_DIR/scripts/"*.sh
chmod +x "$INSTALL_DIR/install.sh"

# Create config if not exists
if [[ ! -f "$INSTALL_DIR/config.sh" ]]; then
    echo -e "${GREEN}📝 Creating config file...${NC}"
    cp "$INSTALL_DIR/config.example.sh" "$INSTALL_DIR/config.sh"
    echo -e "${YELLOW}   ⚠️  Edit $INSTALL_DIR/config.sh with your settings${NC}"
fi

# Create symlinks (may need sudo)
echo -e "${GREEN}🔗 Creating command symlinks...${NC}"

create_symlink() {
    local script="$1"
    local cmd="$2"
    
    # Remove existing symlink if it exists
    if [[ -L "$BIN_DIR/$cmd" ]]; then
        if [[ -w "$BIN_DIR" ]]; then
            rm "$BIN_DIR/$cmd"
        else
            sudo rm "$BIN_DIR/$cmd"
        fi
    fi
    
    if [[ -w "$BIN_DIR" ]]; then
        ln -sf "$INSTALL_DIR/scripts/$script" "$BIN_DIR/$cmd"
    else
        sudo ln -sf "$INSTALL_DIR/scripts/$script" "$BIN_DIR/$cmd"
    fi
    echo -e "   ✅ $cmd → $INSTALL_DIR/scripts/$script"
}

create_symlink "deploy.sh" "deploy"
create_symlink "update.sh" "update"
create_symlink "projects.sh" "projects"

# Done
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ Installation Complete!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Installed to: ${INSTALL_DIR}"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "  1. Edit config: ${CYAN}nano $INSTALL_DIR/config.sh${NC}"
echo -e "  2. Set your PROJECTS_DIR and DO_API_TOKEN"
echo ""
echo -e "  ${CYAN}Commands available:${NC}"
echo -e "  • deploy --help"
echo -e "  • update --help"
echo -e "  • projects --help"
echo ""

