#!/bin/bash
# update.sh - Quick update for existing projects
# Usage: update <project-name> [--rebuild] [--restart] [--logs]

set -e

# Load config (resolve symlinks to find real script location)
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
    LINK_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$LINK_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
CONFIG_FILE="$(dirname "$SCRIPT_DIR")/config.sh"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Defaults
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"

# Help
show_help() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  🔄 Quick Project Update${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Usage: update <project-name> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --rebuild    Force rebuild (no cache)"
    echo "  --restart    Just restart (no git pull)"
    echo "  --logs       Show logs after update"
    echo "  --help       Show this help"
    echo ""
    echo "Examples:"
    echo "  update house_estimator"
    echo "  update house_estimator --rebuild"
    echo "  update house_estimator --restart --logs"
    echo ""
    echo "Projects dir: ${PROJECTS_DIR}"
    echo ""
    echo "Available projects:"
    ls -1 "$PROJECTS_DIR" 2>/dev/null | sed 's/^/  - /' || echo "  (none)"
}

# Parse arguments
PROJECT_NAME=""
FORCE_REBUILD=false
RESTART_ONLY=false
SHOW_LOGS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --rebuild) FORCE_REBUILD=true; shift ;;
        --restart) RESTART_ONLY=true; shift ;;
        --logs) SHOW_LOGS=true; shift ;;
        --help|-h) show_help; exit 0 ;;
        -*) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
        *) PROJECT_NAME="$1"; shift ;;
    esac
done

# Validate
if [[ -z "$PROJECT_NAME" ]]; then
    echo -e "${RED}❌ Project name required${NC}"
    echo ""
    show_help
    exit 1
fi

PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_NAME}"

if [[ ! -d "$PROJECT_DIR" ]]; then
    echo -e "${RED}❌ Project not found: ${PROJECT_DIR}${NC}"
    echo ""
    echo "Available projects:"
    ls -1 "$PROJECTS_DIR" 2>/dev/null | sed 's/^/  - /' || echo "  (none)"
    exit 1
fi

cd "$PROJECT_DIR"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  🔄 Updating: ${PROJECT_NAME}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "master")
echo -e "Branch: ${CURRENT_BRANCH}"

if [[ "$RESTART_ONLY" == "true" ]]; then
    echo -e "${GREEN}🔄 Restarting containers...${NC}"
    docker-compose restart
    echo -e "${GREEN}✅ Restarted${NC}"
else
    echo -e "${GREEN}📥 Pulling latest changes...${NC}"
    
    BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "none")
    git pull origin "$CURRENT_BRANCH"
    AFTER=$(git rev-parse HEAD 2>/dev/null || echo "none")
    
    if [[ "$BEFORE" == "$AFTER" ]] && [[ "$FORCE_REBUILD" != "true" ]]; then
        echo -e "${YELLOW}   No changes. Restarting...${NC}"
        docker-compose restart
    else
        if [[ "$BEFORE" != "$AFTER" ]]; then
            echo -e "${GREEN}   New commits:${NC}"
            git log --oneline "${BEFORE}..${AFTER}" 2>/dev/null | head -5 | sed 's/^/   /'
        fi
        
        echo -e "${GREEN}🐳 Rebuilding...${NC}"
        docker-compose down --remove-orphans
        
        if [[ "$FORCE_REBUILD" == "true" ]]; then
            docker-compose build --no-cache
        else
            docker-compose build
        fi
        
        docker-compose up -d
    fi
    
    echo -e "${GREEN}✅ Update complete${NC}"
fi

# Check status
sleep 2
STATUS=$(docker-compose ps --format "{{.State}}" 2>/dev/null | head -1)

if [[ "$STATUS" == "running" ]]; then
    echo -e "${GREEN}✅ Container running${NC}"
else
    echo -e "${RED}❌ Container issue${NC}"
    docker-compose logs --tail=10
fi

if [[ "$SHOW_LOGS" == "true" ]]; then
    echo ""
    echo -e "${CYAN}📋 Recent logs:${NC}"
    docker-compose logs --tail=20
fi

echo ""

