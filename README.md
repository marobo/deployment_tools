# 🚀 Deploy Tools

Simple deployment scripts for Docker + Traefik servers. Deploy any project with a single command.

## Features

- 🐳 **Docker + Traefik** - Automatic container deployment with reverse proxy
- 🔒 **Auto SSL** - Let's Encrypt certificates via Traefik
- 📡 **DNS Automation** - Auto-create DigitalOcean DNS records
- 🔄 **Quick Updates** - Pull and rebuild with one command
- 📋 **Project Overview** - List all projects with status

## Installation

### One-Command Install

```bash
curl -sSL https://raw.githubusercontent.com/marobo/deployment_tools/main/install.sh | bash
```

### Manual Install

```bash
git clone https://github.com/marobo/deployment_tools.git ~/deployment_tools
cd ~/deployment_tools
./install.sh
```

## Configuration

Edit the config file with your settings:

```bash
nano ~/deployment_tools/config.sh
```

### Required Settings

```bash
# Where your projects are stored
PROJECTS_DIR="/home/you_username/projects"

# Docker network (must match your Traefik setup)
TRAEFIK_NETWORK="proxy"

# DigitalOcean API token (optional, for auto DNS)
DO_API_TOKEN="dop_v1_xxxxx"
```

## Usage

### 🚀 Deploy New Project

```bash
deploy --repo git@github.com:YOU_GIT_USERNAME/myapp.git \
       --subdomain myapp \
       --domain example.com
```

**Options:**

| Flag | Description | Default |
|------|-------------|---------|
| `--repo` | Git repository URL | Required |
| `--subdomain` | Subdomain name | Required |
| `--domain` | Base domain | Required |
| `--port` | App port in container | 8000 |
| `--branch` | Git branch | main |
| `--env-file` | Path to .env file | - |
| `--project-name` | Custom folder name | subdomain |
| `--skip-dns` | Skip DNS creation | false |
| `--rebuild` | Force rebuild | false |

### 🔄 Update Existing Project

```bash
# Simple update (git pull + rebuild if changes)
update myapp

# Force rebuild (no cache)
update myapp --rebuild

# Just restart containers
update myapp --restart

# Show logs after update
update myapp --logs
```

### 📋 List All Projects

```bash
# Simple list
projects

# With container status
projects --status

# With URLs
projects --urls

# Full information
projects --full
```

## Server Structure

```
/home/your_username/
├── traefik/
│   └── docker-compose.yml    # Traefik reverse proxy
└── projects/
    ├── myapp/
    │   ├── docker-compose.yml
    │   ├── Dockerfile
    │   └── .env
    ├── another-app/
    └── api-server/
```

## Requirements

### Server Requirements

- Docker & Docker Compose
- Git
- Traefik (running with `proxy` network)
- jq (for DNS features)

### Project Requirements

Your project needs a `Dockerfile`. If no `docker-compose.yml` exists, one will be generated automatically with Traefik labels.

Example project `docker-compose.yml`:

```yaml
services:
  web:
    build: .
    container_name: myapp_web
    env_file:
      - .env
    restart: always
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=8000"

networks:
  proxy:
    external: true
```

## Traefik Setup

Make sure Traefik is running with the `proxy` network:

```yaml
# /home/your_username/traefik/docker-compose.yml
services:
  traefik:
    image: traefik:v3.0
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=your@email.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    networks:
      - proxy

networks:
  proxy:
    external: true
```

Create the network:

```bash
docker network create proxy
```

## DigitalOcean DNS Setup

1. Go to [DigitalOcean API Tokens](https://cloud.digitalocean.com/account/api/tokens)
2. Generate a new token with read/write access
3. Add to your config:

```bash
# ~/deployment_tools/config.sh
DO_API_TOKEN="dop_v1_your_token_here"
```

## Updating Deploy Tools

```bash
cd ~/deployment_tools
git pull origin master
./install.sh
```

## Troubleshooting

### Container not starting

```bash
cd /home/your_username/projects/myapp
docker compose logs -f
```

### SSL certificate issues

Wait a few minutes for Let's Encrypt. Check Traefik logs:

```bash
cd /home/your_username/traefik
docker compose logs -f
```

### DNS not propagating

Use `--skip-dns` and create records manually, or wait 5-10 minutes.

## License

MIT

