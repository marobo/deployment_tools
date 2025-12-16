# Deployment Scripts - Planning & Design Notes

This document captures the planning conversation and design decisions for this deployment toolkit.

---

## 📋 Original Requirements

**User's Setup:**
- Digital Ocean server with Traefik for reverse proxy
- Multiple projects can be deployed to the same server
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
1. Clone project into server
2. Create subdomain pointed to DNS
3. Setup Docker and run containers
4. Integrate with Traefik for SSL/routing

---

## 🛠️ Solution Design

### Scripts Created

| Script | Purpose |
|--------|---------|
| `deploy.sh` | Full deployment: clone repo, create DNS, setup Docker, deploy |
| `update.sh` | Quick update: git pull + rebuild containers |
| `projects.sh` | List all projects with status and URLs |
| `install.sh` | One-command installer for any server |

### Key Features

1. **DNS Automation** - Uses DigitalOcean API to create A records automatically
2. **Traefik Integration** - Auto-generates docker-compose.yml with Traefik labels
3. **Config-based** - All settings in `config.sh` (not tracked in git)
4. **Idempotent** - Safe to run multiple times

---

## 📖 Usage Examples

### Deploy New Project

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
   └── Pull if exists

3. Setup Environment
   ├── Copy provided .env
   ├── Use existing .env
   └── Or copy from .env.example

4. Setup Docker Compose
   ├── Use existing if has Traefik labels
   └── Generate new with Traefik config

5. Deploy Containers
   ├── Create Traefik network
   ├── Stop existing containers
   ├── Build image
   └── Start containers

6. Health Check
   ├── Verify container running
   └── Test HTTPS endpoint
```

---

## 🚫 Features Excluded (Not Needed Now)

- **GitHub Webhook Receiver** - Auto-deploy on push (can add later)
  - Would run on port 9000
  - Receives POST from GitHub
  - Triggers update script

---

## 📁 Repository Structure

```
deployment_tools/
├── install.sh           # One-command installer
├── config.example.sh    # Configuration template
├── README.md            # User documentation
├── PLANNING.md          # This file
├── .gitignore           # Ignores config.sh
└── scripts/
    ├── deploy.sh        # Full deployment
    ├── update.sh        # Quick update
    └── projects.sh      # List projects
```

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

---

*Generated from planning conversation - December 2024*

