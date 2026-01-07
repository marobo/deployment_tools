# Deployment Scripts - Planning & Design Notes

This document captures the planning conversation and design decisions for this deployment toolkit.

---

## 📋 Original Requirements

**User's Setup:**
- Digital Ocean server with Traefik for reverse proxy
- Multiple Django projects can be deployed to the same server
- Server structure:
  ```
  /home/your_username/
  ├── traefik/
  │   └── docker-compose.yml
  └── projects/
      ├── house_estimator/
      │   ├── docker-compose.yml
      │   ├── .env
      │   └── ...
      └── another_project/
          ├── docker-compose.yml
          ├── .env
          └── ...
  ```

**Desired Features:**
1. Clone Django project into server
2. Create subdomain pointed to DNS
3. Setup Docker and run containers
4. Integrate with Traefik for SSL/routing

---

## 🛠️ Solution Design

### Scripts Created

| Script | Purpose |
|--------|---------|
| `common.sh` | Shared functions, colors, config loading |
| `d.sh` | Quick deploy: one-liner deployment |
| `deploy.sh` | Full deployment: clone repo, create DNS, setup Docker, deploy |
| `update.sh` | Quick update: git pull + rebuild containers |
| `projects.sh` | List all projects with status and URLs |
| `install.sh` | One-command installer for any server |

### Key Features

1. **Django-focused** - Auto-generates Dockerfile from templates for Django projects
2. **DNS Automation** - Uses DigitalOcean API to create A records automatically
3. **Traefik Integration** - Auto-generates docker-compose.yml with Traefik labels
4. **Config-based** - All settings in `config.sh` (not tracked in git)
5. **Idempotent** - Safe to run multiple times
6. **Shared Library** - Common functions in `common.sh` to reduce duplication

---

## 📖 Usage Examples

### Quick Deploy (Recommended)

```bash
# Just the repo URL - subdomain auto-detected from repo name
d git@github.com:user/myapp.git

# Or specify a custom subdomain
d git@github.com:user/myapp.git api
```

### Full Deploy

```bash
deploy --repo git@github.com:your_git_user_name/myapp.git \
       --subdomain myapp \
       --domain mainsite.dev
```

### Update Existing Project

```bash
# Simple update
update myapp

# Force rebuild
update myapp --rebuild

# Just restart
update myapp --restart
```

### List Projects

```bash
# Full info with status and URLs
projects --full
```

---

## 🔧 Deploy Script Options

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

---

## 🏗️ Deployment Flow

```
1. Create DNS Record (DigitalOcean API)
   ├── Get server IP
   ├── Check if record exists
   └── Create/update A record

2. Setup Repository
   ├── Clone if new
   ├── Pull if exists
   └── Update git submodules

3. Setup Environment
   ├── Copy provided .env
   ├── Use existing .env
   └── Or copy from .env.example

4. Setup Dockerfile (Django Template)
   ├── Check if Dockerfile exists
   ├── Detect Django project (requirements.txt or manage.py)
   └── Copy Dockerfile + entrypoint.sh from templates/django/

5. Setup Docker Compose
   ├── Use existing if has Traefik labels
   └── Generate new with Traefik config

6. Deploy Containers
   ├── Create Traefik network
   ├── Stop existing containers
   ├── Build image
   └── Start containers

7. Health Check
   ├── Verify container running
   └── Test HTTPS endpoint
```

---

## 📁 Repository Structure

```
deployment_tools/
├── install.sh              # One-command installer
├── config.example.sh       # Configuration template
├── config.sh               # Your configuration (gitignored)
├── README.md               # User documentation
├── PLANNING.md             # This file
├── .gitignore              # Ignores config.sh
├── scripts/
│   ├── common.sh           # Shared functions & utilities
│   ├── d.sh                # Quick deploy command
│   ├── deploy.sh           # Full deployment script
│   ├── update.sh           # Quick update script
│   └── projects.sh         # List projects script
└── templates/
    └── django/             # Django project templates
        ├── Dockerfile      # Python 3.11 + Gunicorn
        └── entrypoint.sh   # Migrations + collectstatic
```

---

## 🐍 Django Template Details

The `templates/django/` directory contains:

### Dockerfile
- Base image: `python:3.11-slim`
- Installs system deps for PostgreSQL (`libpq-dev`)
- Installs all `requirements.txt` files (including submodules)
- Exposes port 8000
- Runs with Gunicorn

### entrypoint.sh
- Waits for database (3 second delay)
- Runs `python manage.py migrate --noinput`
- Runs `python manage.py collectstatic --noinput`
- Executes the main command (Gunicorn)

---

## 🔐 Security Notes

- `config.sh` is gitignored (contains DO_API_TOKEN)
- Use SSH keys for git clone on server
- Traefik handles SSL certificates

---

## 📝 Installation on Server

```bash
# One-liner
curl -sSL https://raw.githubusercontent.com/marobo/deployment_tools/master/install.sh | bash

# Manual
git clone https://github.com/marobo/deployment_tools.git ~/deployment_tools
cd ~/deployment_tools && ./install.sh

# Configure
nano ~/deployment_tools/config.sh
```

---

## 🔮 Future Improvements (If Needed)

- [ ] Rollback functionality
- [ ] Database backup before deploy
- [ ] Slack/Discord notifications
- [ ] GitHub webhook for auto-deploy
- [ ] Multi-server support
- [ ] Blue-green deployments
- [ ] Support for other frameworks (FastAPI, Flask, etc.)

---

*Last updated: January 2025*
