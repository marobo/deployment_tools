#!/bin/bash
# common.sh - Shared functions for deployment tools
# Source this file in other scripts: source "$SCRIPT_DIR/common.sh"

# ===========================================
# Colors
# ===========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# ===========================================
# Resolve script location (handles symlinks)
# Returns the real directory of the calling script
# ===========================================
resolve_script_dir() {
    local script_path="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
    while [[ -L "$script_path" ]]; do
        local link_dir="$(cd "$(dirname "$script_path")" && pwd)"
        script_path="$(readlink "$script_path")"
        [[ "$script_path" != /* ]] && script_path="$link_dir/$script_path"
    done
    echo "$(cd "$(dirname "$script_path")" && pwd)"
}

# ===========================================
# Load configuration
# ===========================================
load_config() {
    local script_dir="$1"
    local config_file="$(dirname "$script_dir")/config.sh"
    
    if [[ -f "$config_file" ]]; then
        source "$config_file"
    fi
    
    # Set defaults (can be overridden by config.sh)
    PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"
    TRAEFIK_NETWORK="${TRAEFIK_NETWORK:-proxy}"
    DO_API_TOKEN="${DO_API_TOKEN:-}"
    DEFAULT_PORT="${DEFAULT_PORT:-8000}"
    DEFAULT_BRANCH="${DEFAULT_BRANCH:-master}"
    DEFAULT_DOMAIN="${DEFAULT_DOMAIN:-}"
    
    # Export for use in scripts
    export PROJECTS_DIR TRAEFIK_NETWORK DO_API_TOKEN DEFAULT_PORT DEFAULT_BRANCH DEFAULT_DOMAIN
}

# ===========================================
# Print styled header
# ===========================================
print_header() {
    local title="$1"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $title${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ===========================================
# Print wide styled header
# ===========================================
print_wide_header() {
    local title="$1"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $title${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ===========================================
# Check container status
# ===========================================
check_container_status() {
    local project_dir="$1"
    cd "$project_dir"
    docker-compose ps --format "{{.State}}" 2>/dev/null | head -1
}

# ===========================================
# Extract URL from docker-compose.yml (portable, works on macOS)
# ===========================================
get_project_url() {
    local compose_file="$1"
    awk -F'`' '/Host\(/ {print $2; exit}' "$compose_file" 2>/dev/null
}

# ===========================================
# Extract repo name from git URL
# ===========================================
get_repo_name() {
    local repo_url="$1"
    basename "$repo_url" .git
}

