#!/bin/bash
# deploy.sh - Full deployment script for new projects
# Usage: deploy --repo <git-url> --subdomain <name> --domain <domain>

set -e

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

# Defaults (can be overridden by config.sh)
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"
TRAEFIK_NETWORK="${TRAEFIK_NETWORK:-proxy}"
DO_API_TOKEN="${DO_API_TOKEN:-}"
DEFAULT_PORT="${DEFAULT_PORT:-8000}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

# Help
show_help() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  🚀 Project Deployment Script${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Usage: deploy [OPTIONS]"
    echo ""
    echo "Required:"
    echo "  --repo          Git repository URL"
    echo "  --subdomain     Subdomain name (e.g., 'myapp')"
    echo "  --domain        Base domain (e.g., 'example.com')"
    echo ""
    echo "Optional:"
    echo "  --port          App port (default: ${DEFAULT_PORT})"
    echo "  --branch        Git branch (default: ${DEFAULT_BRANCH})"
    echo "  --env-file      Path to .env file to copy"
    echo "  --project-name  Custom folder name (default: subdomain)"
    echo "  --skip-dns      Skip DNS record creation"
    echo "  --rebuild       Force rebuild without cache"
    echo "  --help          Show this help"
    echo ""
    echo "Examples:"
    echo "  deploy --repo git@github.com:user/app.git --subdomain myapp --domain example.com"
    echo "  deploy --repo git@github.com:user/api.git --subdomain api --domain example.com --port 3000"
    echo ""
    echo "Config: ${CONFIG_FILE}"
    echo "Projects: ${PROJECTS_DIR}"
}

# Parse arguments
REPO_URL=""
SUBDOMAIN=""
BASE_DOMAIN=""
APP_PORT="$DEFAULT_PORT"
BRANCH="$DEFAULT_BRANCH"
ENV_FILE=""
PROJECT_NAME=""
SKIP_DNS=false
FORCE_REBUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --repo) REPO_URL="$2"; shift 2 ;;
        --subdomain) SUBDOMAIN="$2"; shift 2 ;;
        --domain) BASE_DOMAIN="$2"; shift 2 ;;
        --port) APP_PORT="$2"; shift 2 ;;
        --branch) BRANCH="$2"; shift 2 ;;
        --env-file) ENV_FILE="$2"; shift 2 ;;
        --project-name) PROJECT_NAME="$2"; shift 2 ;;
        --skip-dns) SKIP_DNS=true; shift ;;
        --rebuild) FORCE_REBUILD=true; shift ;;
        --help|-h) show_help; exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; show_help; exit 1 ;;
    esac
done

# Set derived values
PROJECT_NAME="${PROJECT_NAME:-$SUBDOMAIN}"
FULL_DOMAIN="${SUBDOMAIN}.${BASE_DOMAIN}"
PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_NAME}"

# Validation
if [[ -z "$REPO_URL" ]] || [[ -z "$SUBDOMAIN" ]] || [[ -z "$BASE_DOMAIN" ]]; then
    echo -e "${RED}❌ Error: --repo, --subdomain, and --domain are required${NC}"
    echo ""
    show_help
    exit 1
fi

# Print summary
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  🚀 Deploying: ${FULL_DOMAIN}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Repository:  ${REPO_URL}"
echo -e "  Branch:      ${BRANCH}"
echo -e "  Directory:   ${PROJECT_DIR}"
echo -e "  App Port:    ${APP_PORT}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 1: Create DNS Record
create_dns_record() {
    if [[ "$SKIP_DNS" == "true" ]]; then
        echo -e "${YELLOW}⏭️  Skipping DNS creation (--skip-dns)${NC}"
        return 0
    fi

    if [[ -z "$DO_API_TOKEN" ]]; then
        echo -e "${YELLOW}⚠️  DO_API_TOKEN not set in config${NC}"
        echo -e "${YELLOW}   Edit: ${CONFIG_FILE}${NC}"
        echo -e "${YELLOW}   Or create DNS record manually for ${FULL_DOMAIN}${NC}"
        echo ""
        read -p "Continue without DNS setup? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        return 0
    fi

    echo -e "${GREEN}📡 Step 1: Creating DNS record...${NC}"
    
    SERVER_IP=$(curl -s ifconfig.me)
    echo -e "   Server IP: ${SERVER_IP}"
    
    EXISTING=$(curl -s -X GET \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${DO_API_TOKEN}" \
        "https://api.digitalocean.com/v2/domains/${BASE_DOMAIN}/records" | \
        jq -r ".domain_records[] | select(.name == \"${SUBDOMAIN}\") | .id" 2>/dev/null || echo "")
    
    if [[ -n "$EXISTING" && "$EXISTING" != "null" ]]; then
        echo -e "   Record exists. Updating..."
        curl -s -X PUT \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${DO_API_TOKEN}" \
            -d "{\"data\": \"${SERVER_IP}\"}" \
            "https://api.digitalocean.com/v2/domains/${BASE_DOMAIN}/records/${EXISTING}" > /dev/null
    else
        echo -e "   Creating new A record..."
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${DO_API_TOKEN}" \
            -d "{\"type\": \"A\", \"name\": \"${SUBDOMAIN}\", \"data\": \"${SERVER_IP}\", \"ttl\": 300}" \
            "https://api.digitalocean.com/v2/domains/${BASE_DOMAIN}/records" > /dev/null
    fi
    
    echo -e "   ${GREEN}✅ DNS record ready${NC}"
    echo ""
}

# Step 2: Clone or Update Repository
setup_repository() {
    echo -e "${GREEN}📦 Step 2: Setting up repository...${NC}"
    
    mkdir -p "$PROJECTS_DIR"
    
    if [[ -d "$PROJECT_DIR/.git" ]]; then
        echo -e "   Project exists. Pulling latest..."
        cd "$PROJECT_DIR"
        git stash 2>/dev/null || true
        git fetch origin
        git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/$BRANCH"
        git pull origin "$BRANCH"
    else
        echo -e "   Cloning repository..."
        rm -rf "$PROJECT_DIR" 2>/dev/null || true
        git clone -b "$BRANCH" "$REPO_URL" "$PROJECT_DIR"
        cd "$PROJECT_DIR"
    fi
    
    echo -e "   ${GREEN}✅ Repository ready${NC}"
    echo ""
}

# Step 3: Setup Environment
setup_environment() {
    echo -e "${GREEN}🔧 Step 3: Setting up environment...${NC}"
    
    cd "$PROJECT_DIR"
    
    if [[ -n "$ENV_FILE" ]]; then
        if [[ -f "$ENV_FILE" ]]; then
            cp "$ENV_FILE" "${PROJECT_DIR}/.env"
            echo -e "   ${GREEN}✅ Copied .env from ${ENV_FILE}${NC}"
        else
            echo -e "   ${RED}❌ Env file not found: ${ENV_FILE}${NC}"
            exit 1
        fi
    elif [[ -f ".env" ]]; then
        echo -e "   ${GREEN}✅ Using existing .env${NC}"
    elif [[ -f ".env.example" ]]; then
        cp ".env.example" ".env"
        echo -e "   ${YELLOW}⚠️  Copied .env.example → .env (edit with real values!)${NC}"
    else
        echo -e "   ${YELLOW}⚠️  No .env file. Create one if needed.${NC}"
    fi
    echo ""
}

# Step 4: Setup Docker Compose
setup_docker_compose() {
    echo -e "${GREEN}🐳 Step 4: Checking Docker config...${NC}"
    
    cd "$PROJECT_DIR"
    
    if [[ -f "docker-compose.yml" ]]; then
        if grep -q "traefik.enable=true" docker-compose.yml; then
            echo -e "   ${GREEN}✅ docker-compose.yml with Traefik found${NC}"
        else
            echo -e "   ${YELLOW}⚠️  docker-compose.yml missing Traefik labels${NC}"
        fi
    elif [[ -f "Dockerfile" ]] || [[ -f "dockerfile" ]]; then
        echo -e "   Generating docker-compose.yml..."
        
        cat > docker-compose.yml << EOF
services:
  web:
    build: .
    container_name: ${PROJECT_NAME}_web
    volumes:
      - .:/app
    env_file:
      - .env
    restart: always
    networks:
      - ${TRAEFIK_NETWORK}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${PROJECT_NAME}.rule=Host(\`${FULL_DOMAIN}\`)"
      - "traefik.http.routers.${PROJECT_NAME}.entrypoints=websecure"
      - "traefik.http.routers.${PROJECT_NAME}.tls.certresolver=letsencrypt"
      - "traefik.http.services.${PROJECT_NAME}.loadbalancer.server.port=${APP_PORT}"

networks:
  ${TRAEFIK_NETWORK}:
    external: true
EOF
        echo -e "   ${GREEN}✅ docker-compose.yml generated${NC}"
    else
        echo -e "   ${RED}❌ No Dockerfile found${NC}"
        exit 1
    fi
    echo ""
}

# Step 5: Deploy
deploy_containers() {
    echo -e "${GREEN}🚢 Step 5: Building and deploying...${NC}"
    
    cd "$PROJECT_DIR"
    
    docker network create "$TRAEFIK_NETWORK" 2>/dev/null || true
    
    echo -e "   Stopping existing containers..."
    docker compose down --remove-orphans 2>/dev/null || true
    
    echo -e "   Building..."
    if [[ "$FORCE_REBUILD" == "true" ]]; then
        docker compose build --no-cache
    else
        docker compose build
    fi
    
    echo -e "   Starting..."
    docker compose up -d
    
    echo -e "   ${GREEN}✅ Containers deployed${NC}"
    echo ""
}

# Step 6: Health Check
health_check() {
    echo -e "${GREEN}🏥 Step 6: Health check...${NC}"
    
    cd "$PROJECT_DIR"
    sleep 3
    
    CONTAINER_STATUS=$(docker compose ps --format "{{.State}}" 2>/dev/null | head -1)
    
    if [[ "$CONTAINER_STATUS" == "running" ]]; then
        echo -e "   ${GREEN}✅ Container is running${NC}"
    else
        echo -e "   ${RED}❌ Container issue${NC}"
        docker compose logs --tail=15
        exit 1
    fi
    
    echo -e "   Waiting for HTTPS (20s)..."
    sleep 20
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://${FULL_DOMAIN}" 2>/dev/null || echo "000")
    
    case $HTTP_CODE in
        200|301|302|304) echo -e "   ${GREEN}✅ Site accessible (HTTP ${HTTP_CODE})${NC}" ;;
        000) echo -e "   ${YELLOW}⚠️  Cannot connect. DNS may be propagating.${NC}" ;;
        *) echo -e "   ${YELLOW}⚠️  HTTP ${HTTP_CODE}${NC}" ;;
    esac
    echo ""
}

# Print summary
print_summary() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  🎉 Deployment Complete!${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  🌐 URL: https://${FULL_DOMAIN}"
    echo -e "  📁 Dir: ${PROJECT_DIR}"
    echo ""
    echo -e "  Commands:"
    echo -e "  ├─ Logs:    cd ${PROJECT_DIR} && docker compose logs -f"
    echo -e "  ├─ Restart: cd ${PROJECT_DIR} && docker compose restart"
    echo -e "  └─ Update:  update ${PROJECT_NAME}"
    echo ""
}

# Main
main() {
    create_dns_record
    setup_repository
    setup_environment
    setup_docker_compose
    deploy_containers
    health_check
    print_summary
}

main

