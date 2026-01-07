#!/bin/bash
# d.sh - Dead simple deployment
# Usage: d <git-url> [subdomain]
# 
# Examples:
#   d git@github.com:user/myapp.git              → deploys to myapp.YOUR_DOMAIN
#   d git@github.com:user/myapp.git api          → deploys to api.YOUR_DOMAIN
#   d https://github.com/user/cool-project.git   → deploys to cool-project.YOUR_DOMAIN

set -e

# Resolve symlinks to find real script location
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
    LINK_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$LINK_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Load shared functions
source "$SCRIPT_DIR/common.sh"
load_config "$SCRIPT_DIR"

# Help
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]] || [[ -z "$1" ]]; then
    print_header "⚡ Quick Deploy"
    echo "Usage: d <git-url> [subdomain]"
    echo ""
    echo "Examples:"
    echo "  d git@github.com:user/myapp.git"
    echo "  d git@github.com:user/myapp.git api"
    echo "  d https://github.com/user/project.git"
    echo ""
    if [[ -n "$DEFAULT_DOMAIN" ]]; then
        echo -e "Default domain: ${GREEN}${DEFAULT_DOMAIN}${NC}"
    else
        echo -e "${YELLOW}⚠️  Set DEFAULT_DOMAIN in config.sh for one-liner deploys${NC}"
        echo ""
        echo "Add this to ~/deployment_tools/config.sh:"
        echo "  DEFAULT_DOMAIN=\"example.com\""
    fi
    echo ""
    exit 0
fi

REPO_URL="$1"
SUBDOMAIN="$2"

# Extract repo name from URL using basename (simple and portable)
if [[ -z "$SUBDOMAIN" ]]; then
    SUBDOMAIN=$(get_repo_name "$REPO_URL")
fi

# Clean subdomain (lowercase, replace underscores with dashes)
SUBDOMAIN=$(echo "$SUBDOMAIN" | tr '[:upper:]' '[:lower:]' | tr '_' '-')

# Check domain
if [[ -z "$DEFAULT_DOMAIN" ]]; then
    echo -e "${YELLOW}No DEFAULT_DOMAIN set. Enter domain:${NC}"
    read -p "Domain (e.g., example.com): " DEFAULT_DOMAIN
    
    if [[ -z "$DEFAULT_DOMAIN" ]]; then
        echo -e "${RED}❌ Domain required${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${YELLOW}💡 Tip: Add to config.sh to skip this next time:${NC}"
    echo "   DEFAULT_DOMAIN=\"${DEFAULT_DOMAIN}\""
    echo ""
fi

# Confirm
print_header "⚡ Quick Deploy"
echo -e "  Repo:   ${REPO_URL}"
echo -e "  URL:    ${GREEN}https://${SUBDOMAIN}.${DEFAULT_DOMAIN}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -p "Deploy? (Y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Run the full deploy script
exec "${SCRIPT_DIR}/deploy.sh" \
    --repo "$REPO_URL" \
    --subdomain "$SUBDOMAIN" \
    --domain "$DEFAULT_DOMAIN"
