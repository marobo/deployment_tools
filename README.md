# 🚀 Deploy Tools

Deploy Django projects with a **single command**.

```bash
d git@github.com:user/myapp.git
```

That's it. Seriously.

---

## Features

- ⚡ **One-command deploy** - Just paste your git URL
- 🐍 **Django-focused** - Auto-generates Dockerfile and entrypoint for Django
- 🐳 **Docker + Traefik** - Automatic container deployment with reverse proxy
- 🔒 **Auto SSL** - Let's Encrypt certificates via Traefik
- 📡 **DNS Automation** - Auto-create DigitalOcean DNS records
- 🔄 **Quick Updates** - Pull and rebuild with one command
- 📋 **Project Overview** - List all projects with status

## Installation

### One-Command Install

```bash
curl -sSL https://raw.githubusercontent.com/marobo/deployment_tools/master/install.sh | bash
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
PROJECTS_DIR="/home/your_username/projects"

# Docker network (must match your Traefik setup)
TRAEFIK_NETWORK="proxy"

# Default domain for quick deploys
DEFAULT_DOMAIN="example.com"

# DigitalOcean API token (optional, for auto DNS)
DO_API_TOKEN="dop_v1_xxxxx"
```

## Usage

### ⚡ Quick Deploy (Recommended)

```bash
# Just the repo URL - subdomain auto-detected from repo name
d git@github.com:user/myapp.git

# Or specify a custom subdomain
d git@github.com:user/myapp.git api
```

First, set your default domain in config:
```bash
nano ~/deployment_tools/config.sh
# Set: DEFAULT_DOMAIN="yourdomain.com"
```

### 🚀 Full Deploy (More Options)

```bash
deploy --repo git@github.com:user/myapp.git \
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
| `--branch` | Git branch | master |
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
├── deployment_tools/         # This toolkit
│   ├── scripts/
│   │   ├── common.sh         # Shared functions
│   │   ├── d.sh              # Quick deploy
│   │   ├── deploy.sh         # Full deploy
│   │   ├── update.sh         # Update projects
│   │   └── projects.sh       # List projects
│   ├── templates/
│   │   └── django/           # Django Dockerfile templates
│   │       ├── Dockerfile
│   │       └── entrypoint.sh
│   └── config.sh             # Your configuration
├── traefik/
│   └── docker-compose.yml    # Traefik reverse proxy
└── projects/
    ├── myapp/
    │   ├── docker-compose.yml
    │   ├── Dockerfile
    │   ├── entrypoint.sh
    │   └── .env
    └── another-app/
```

## Requirements

### Server Requirements

- Docker & Docker Compose
- Git
- Traefik (running with `proxy` network)
- jq (for DNS features)

### Project Requirements

Your Django project needs:
- `requirements.txt` or `manage.py` (for auto-detection)
- If no `Dockerfile` exists, one will be generated from the Django template
- If no `docker-compose.yml` exists, one will be generated with Traefik labels

The auto-generated Dockerfile:
- Uses Python 3.11
- Runs database migrations automatically
- Collects static files
- Runs with Gunicorn on port 8000

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

### Django migrations failing

Check if your database is accessible and the `.env` file has correct credentials:

```bash
cd /home/your_username/projects/myapp
cat .env
docker compose exec web python manage.py migrate --check
```

## License

MIT
