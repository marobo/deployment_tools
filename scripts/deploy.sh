#!/bin/bash
# deploy.sh - Full deployment script for new projects
# Usage: deploy --repo <git-url> --subdomain <name> --domain <domain>

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

# Defaults (can be overridden by config.sh)
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"
TRAEFIK_NETWORK="${TRAEFIK_NETWORK:-proxy}"
DO_API_TOKEN="${DO_API_TOKEN:-}"
DEFAULT_PORT="${DEFAULT_PORT:-8000}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-master}"

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
PROJECT_DIR="${HOME}/projects/${PROJECT_NAME}"

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
    
    # Initialize and update git submodules if any
    if [[ -f ".gitmodules" ]]; then
        echo -e "   📦 Initializing git submodules..."
        git submodule update --init --recursive
        echo -e "   ${GREEN}✅ Submodules ready${NC}"
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
        # Create empty .env file so docker-compose doesn't fail
        touch .env
        echo -e "   ${YELLOW}⚠️  Created empty .env file${NC}"
    fi
    echo ""
}

# Step 4: Detect project type and generate Dockerfile if needed
generate_dockerfile() {
    echo -e "${GREEN}🔍 Step 4: Detecting project type...${NC}"
    
    cd "$PROJECT_DIR"
    
    # Skip if Dockerfile already exists
    if [[ -f "Dockerfile" ]] || [[ -f "dockerfile" ]]; then
        echo -e "   ${GREEN}✅ Dockerfile found${NC}"
        return 0
    fi
    
    # Detect Python project
    if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]] || [[ -f "Pipfile" ]]; then
        echo -e "   📦 Detected: ${CYAN}Python${NC} project"
        
        # Check for common Python frameworks
        if [[ -f "requirements.txt" ]]; then
            if grep -qi "fastapi\|uvicorn" requirements.txt 2>/dev/null; then
                echo -e "   🚀 Framework: FastAPI"
                cat > Dockerfile << 'DOCKERFILE'
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Make entrypoint executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DOCKERFILE
                cat > entrypoint.sh << 'ENTRYPOINT'
#!/bin/bash
set -e

# Run database migrations if alembic is available
if command -v alembic &> /dev/null; then
    echo "Running database migrations..."
    alembic upgrade head || true
fi

# Execute the main command
exec "$@"
ENTRYPOINT
                
            elif grep -qi "django" requirements.txt 2>/dev/null; then
                echo -e "   🚀 Framework: Django"
                cat > Dockerfile << 'DOCKERFILE'
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Make entrypoint executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "config.wsgi:application"]
DOCKERFILE
                cat > entrypoint.sh << 'ENTRYPOINT'
#!/bin/bash
set -e

# Wait for database to be ready
echo "Waiting for database..."
sleep 3

# Run database migrations
echo "Running database migrations..."
python manage.py migrate --noinput || true

# Collect static files
echo "Collecting static files..."
python manage.py collectstatic --noinput || true

# Execute the main command
exec "$@"
ENTRYPOINT
                
            elif grep -qi "flask" requirements.txt 2>/dev/null; then
                echo -e "   🚀 Framework: Flask"
                cat > Dockerfile << 'DOCKERFILE'
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt gunicorn

# Copy application
COPY . .

# Make entrypoint executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
DOCKERFILE
                cat > entrypoint.sh << 'ENTRYPOINT'
#!/bin/bash
set -e

# Run database migrations if flask-migrate is available
if python -c "import flask_migrate" 2>/dev/null; then
    echo "Running database migrations..."
    flask db upgrade || true
fi

# Execute the main command
exec "$@"
ENTRYPOINT
                
            else
                echo -e "   🚀 Framework: Generic Python"
                cat > Dockerfile << 'DOCKERFILE'
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Make entrypoint executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["python", "main.py"]
DOCKERFILE
                cat > entrypoint.sh << 'ENTRYPOINT'
#!/bin/bash
set -e

# Execute the main command
exec "$@"
ENTRYPOINT
            fi
        else
            # pyproject.toml or Pipfile based project
            cat > Dockerfile << 'DOCKERFILE'
FROM python:3.11-slim

WORKDIR /app

# Copy dependency files
COPY pyproject.toml* Pipfile* ./

# Install pip tools and dependencies
RUN pip install --no-cache-dir pip --upgrade && \
    if [ -f "pyproject.toml" ]; then pip install --no-cache-dir .; \
    elif [ -f "Pipfile" ]; then pip install --no-cache-dir pipenv && pipenv install --system; \
    fi

# Copy application
COPY . .

# Make entrypoint executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["python", "main.py"]
DOCKERFILE
            cat > entrypoint.sh << 'ENTRYPOINT'
#!/bin/bash
set -e

# Execute the main command
exec "$@"
ENTRYPOINT
        fi
        echo -e "   ${GREEN}✅ Dockerfile and entrypoint.sh generated for Python${NC}"
        
    # Detect Node.js project
    elif [[ -f "package.json" ]]; then
        echo -e "   📦 Detected: ${CYAN}Node.js${NC} project"
        
        # Check for common frameworks
        if grep -q '"next"' package.json 2>/dev/null; then
            echo -e "   🚀 Framework: Next.js"
            cat > Dockerfile << 'DOCKERFILE'
FROM node:20-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy application
COPY . .

# Build
RUN npm run build

# Make entrypoint executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["npm", "start"]
DOCKERFILE
            cat > entrypoint.sh << 'ENTRYPOINT'
#!/bin/sh
set -e

# Run database migrations if prisma is available
if [ -f "node_modules/.bin/prisma" ]; then
    echo "Running Prisma migrations..."
    npx prisma migrate deploy || true
fi

# Execute the main command
exec "$@"
ENTRYPOINT
            
        elif grep -q '"nuxt"' package.json 2>/dev/null; then
            echo -e "   🚀 Framework: Nuxt.js"
            cat > Dockerfile << 'DOCKERFILE'
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Make entrypoint executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["npm", "start"]
DOCKERFILE
            cat > entrypoint.sh << 'ENTRYPOINT'
#!/bin/sh
set -e

# Execute the main command
exec "$@"
ENTRYPOINT
            
        else
            echo -e "   🚀 Framework: Generic Node.js"
            cat > Dockerfile << 'DOCKERFILE'
FROM node:20-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application
COPY . .

# Make entrypoint executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["npm", "start"]
DOCKERFILE
            cat > entrypoint.sh << 'ENTRYPOINT'
#!/bin/sh
set -e

# Run database migrations if prisma is available
if [ -f "node_modules/.bin/prisma" ]; then
    echo "Running Prisma migrations..."
    npx prisma migrate deploy || true
fi

# Execute the main command
exec "$@"
ENTRYPOINT
        fi
        echo -e "   ${GREEN}✅ Dockerfile and entrypoint.sh generated for Node.js${NC}"
        
    # Detect Go project
    elif [[ -f "go.mod" ]]; then
        echo -e "   📦 Detected: ${CYAN}Go${NC} project"
        cat > Dockerfile << 'DOCKERFILE'
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod go.sum* ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/main .
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
CMD ["./main"]
DOCKERFILE
        cat > entrypoint.sh << 'ENTRYPOINT'
#!/bin/sh
set -e

# Execute the main command
exec "$@"
ENTRYPOINT
        echo -e "   ${GREEN}✅ Dockerfile and entrypoint.sh generated for Go${NC}"
        
    # Detect PHP project
    elif [[ -f "composer.json" ]] || [[ -f "index.php" ]]; then
        echo -e "   📦 Detected: ${CYAN}PHP${NC} project"
        
        if grep -q '"laravel/framework"' composer.json 2>/dev/null; then
            echo -e "   🚀 Framework: Laravel"
            cat > Dockerfile << 'DOCKERFILE'
FROM php:8.2-fpm

WORKDIR /var/www/html

RUN apt-get update && apt-get install -y \
    git curl libpng-dev libonig-dev libxml2-dev zip unzip \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

COPY . .
RUN composer install --no-dev --optimize-autoloader

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
RUN chown -R www-data:www-data /var/www/html/storage

EXPOSE 9000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
DOCKERFILE
            cat > entrypoint.sh << 'ENTRYPOINT'
#!/bin/bash
set -e

# Wait for database
echo "Waiting for database..."
sleep 3

# Run migrations
echo "Running database migrations..."
php artisan migrate --force || true

# Clear and cache config
php artisan config:cache || true
php artisan route:cache || true
php artisan view:cache || true

# Execute the main command
exec "$@"
ENTRYPOINT
        else
            cat > Dockerfile << 'DOCKERFILE'
FROM php:8.2-apache

WORKDIR /var/www/html

COPY . .
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN chown -R www-data:www-data /var/www/html

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
DOCKERFILE
            cat > entrypoint.sh << 'ENTRYPOINT'
#!/bin/bash
set -e

# Execute the main command
exec "$@"
ENTRYPOINT
        fi
        echo -e "   ${GREEN}✅ Dockerfile and entrypoint.sh generated for PHP${NC}"
        
    # Detect static HTML project
    elif [[ -f "index.html" ]]; then
        echo -e "   📦 Detected: ${CYAN}Static HTML${NC} project"
        cat > Dockerfile << 'DOCKERFILE'
FROM nginx:alpine

COPY . /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
DOCKERFILE
        echo -e "   ${GREEN}✅ Dockerfile generated for static site${NC}"
        
    # Detect Ruby project
    elif [[ -f "Gemfile" ]]; then
        echo -e "   📦 Detected: ${CYAN}Ruby${NC} project"
        cat > Dockerfile << 'DOCKERFILE'
FROM ruby:3.2-slim

WORKDIR /app

RUN apt-get update && apt-get install -y build-essential libpq-dev

COPY Gemfile Gemfile.lock* ./
RUN bundle install

COPY . .
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
DOCKERFILE
        cat > entrypoint.sh << 'ENTRYPOINT'
#!/bin/bash
set -e

# Wait for database
echo "Waiting for database..."
sleep 3

# Run database migrations
echo "Running database migrations..."
bundle exec rails db:migrate || true

# Precompile assets
echo "Precompiling assets..."
bundle exec rails assets:precompile || true

# Execute the main command
exec "$@"
ENTRYPOINT
        echo -e "   ${GREEN}✅ Dockerfile and entrypoint.sh generated for Ruby${NC}"
        
    else
        echo -e "   ${RED}❌ Could not detect project type${NC}"
        echo -e "   ${YELLOW}   No requirements.txt, package.json, go.mod, or Gemfile found${NC}"
        echo -e "   ${YELLOW}   Please add a Dockerfile manually${NC}"
        exit 1
    fi
    echo ""
}

# Step 5: Setup Docker Compose
setup_docker_compose() {
    echo -e "${GREEN}🐳 Step 5: Setting up Docker Compose...${NC}"
    
    cd "$PROJECT_DIR"
    
    if [[ -f "docker-compose.yml" ]]; then
        if grep -q "traefik.enable=true" docker-compose.yml; then
            echo -e "   ${GREEN}✅ docker-compose.yml with Traefik found${NC}"
        else
            echo -e "   ${YELLOW}⚠️  docker-compose.yml missing Traefik labels${NC}"
        fi
    else
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
    fi
    echo ""
}

# Step 6: Deploy
deploy_containers() {
    echo -e "${GREEN}🚢 Step 6: Building and deploying...${NC}"
    
    cd "$PROJECT_DIR"
    
    docker network create "$TRAEFIK_NETWORK" 2>/dev/null || true
    
    echo -e "   Stopping existing containers..."
    docker-compose down --remove-orphans 2>/dev/null || true
    
    echo -e "   Building..."
    if [[ "$FORCE_REBUILD" == "true" ]]; then
        docker-compose build --no-cache
    else
        docker-compose build
    fi
    
    echo -e "   Starting..."
    docker-compose up -d
    
    echo -e "   ${GREEN}✅ Containers deployed${NC}"
    echo ""
}

# Step 7: Health Check
health_check() {
    echo -e "${GREEN}🏥 Step 7: Health check...${NC}"
    
    cd "$PROJECT_DIR"
    sleep 3
    
    CONTAINER_STATUS=$(docker-compose ps --format "{{.State}}" 2>/dev/null | head -1)
    
    if [[ "$CONTAINER_STATUS" == "running" ]]; then
        echo -e "   ${GREEN}✅ Container is running${NC}"
    else
        echo -e "   ${RED}❌ Container issue${NC}"
        docker-compose logs --tail=15
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
    echo -e "  ├─ Logs:    cd ${PROJECT_DIR} && docker-compose logs -f"
    echo -e "  ├─ Restart: cd ${PROJECT_DIR} && docker-compose restart"
    echo -e "  └─ Update:  update ${PROJECT_NAME}"
    echo ""
}

# Main
main() {
    create_dns_record
    setup_repository
    setup_environment
    generate_dockerfile
    setup_docker_compose
    deploy_containers
    health_check
    print_summary
}

main

