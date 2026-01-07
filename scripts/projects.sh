#!/bin/bash
# projects.sh - List all deployed projects
# Usage: projects [--status] [--urls] [--full]

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
show_help() {
    print_header "📦 List Deployed Projects"
    echo "Usage: projects [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --status    Show container status"
    echo "  --urls      Show project URLs"
    echo "  --full      Show all info (status + urls)"
    echo "  --help      Show this help"
    echo ""
    echo "Projects dir: ${PROJECTS_DIR}"
}

# Parse arguments
SHOW_STATUS=false
SHOW_URLS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --status) SHOW_STATUS=true; shift ;;
        --urls) SHOW_URLS=true; shift ;;
        --full) SHOW_STATUS=true; SHOW_URLS=true; shift ;;
        --help|-h) show_help; exit 0 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

print_wide_header "📦 Deployed Projects"

if [[ ! -d "$PROJECTS_DIR" ]]; then
    echo -e "${YELLOW}No projects directory at ${PROJECTS_DIR}${NC}"
    echo -e "${YELLOW}Create it or update PROJECTS_DIR in config.sh${NC}"
    exit 0
fi

PROJECTS=$(ls -1 "$PROJECTS_DIR" 2>/dev/null)

if [[ -z "$PROJECTS" ]]; then
    echo -e "${YELLOW}No projects found in ${PROJECTS_DIR}${NC}"
    exit 0
fi

TOTAL=0
RUNNING=0
STOPPED=0

# Header
printf "  %-25s" "PROJECT"
if [[ "$SHOW_STATUS" == "true" ]]; then
    printf "%-12s" "STATUS"
fi
if [[ "$SHOW_URLS" == "true" ]]; then
    printf "%-40s" "URL"
fi
printf "%-12s\n" "BRANCH"

printf "  %-25s" "─────────────────────────"
if [[ "$SHOW_STATUS" == "true" ]]; then
    printf "%-12s" "──────────"
fi
if [[ "$SHOW_URLS" == "true" ]]; then
    printf "%-40s" "────────────────────────────────────────"
fi
printf "%-12s\n" "──────────"

for PROJECT in $PROJECTS; do
    PROJECT_PATH="${PROJECTS_DIR}/${PROJECT}"
    
    [[ ! -d "$PROJECT_PATH" ]] && continue
    
    ((TOTAL++))
    
    printf "  ${GREEN}%-25s${NC}" "$PROJECT"
    
    if [[ "$SHOW_STATUS" == "true" ]]; then
        if [[ -f "${PROJECT_PATH}/docker-compose.yml" ]]; then
            STATUS=$(check_container_status "$PROJECT_PATH")
            
            case "$STATUS" in
                "running")
                    printf "${GREEN}%-12s${NC}" "● Running"
                    ((RUNNING++))
                    ;;
                "exited"|"dead")
                    printf "${RED}%-12s${NC}" "○ Stopped"
                    ((STOPPED++))
                    ;;
                *)
                    printf "${YELLOW}%-12s${NC}" "? Unknown"
                    ;;
            esac
        else
            printf "${GRAY}%-12s${NC}" "- No Docker"
        fi
    fi
    
    if [[ "$SHOW_URLS" == "true" ]]; then
        if [[ -f "${PROJECT_PATH}/docker-compose.yml" ]]; then
            URL=$(get_project_url "${PROJECT_PATH}/docker-compose.yml")
            if [[ -n "$URL" ]]; then
                printf "${CYAN}%-40s${NC}" "https://${URL}"
            else
                printf "${GRAY}%-40s${NC}" "-"
            fi
        else
            printf "${GRAY}%-40s${NC}" "-"
        fi
    fi
    
    if [[ -d "${PROJECT_PATH}/.git" ]]; then
        cd "$PROJECT_PATH"
        BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "-")
        printf "${YELLOW}%-12s${NC}" "$BRANCH"
    else
        printf "${GRAY}%-12s${NC}" "-"
    fi
    
    echo ""
done

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Total: ${TOTAL} projects"
if [[ "$SHOW_STATUS" == "true" ]]; then
    echo -e "  Running: ${GREEN}${RUNNING}${NC} | Stopped: ${RED}${STOPPED}${NC}"
fi
echo ""
