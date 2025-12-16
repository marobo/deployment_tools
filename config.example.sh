#!/bin/bash
# config.sh - Deploy Tools Configuration
# Copy this to config.sh and edit with your values

# ===========================================
# Server Configuration
# ===========================================

# Where projects are stored on the server
PROJECTS_DIR="/home/onorio/projects"

# Docker network for Traefik
TRAEFIK_NETWORK="proxy"

# ===========================================
# DigitalOcean Configuration (for DNS)
# ===========================================

# Get your token from: https://cloud.digitalocean.com/account/api/tokens
# Leave empty to skip automatic DNS setup
DO_API_TOKEN=""

# ===========================================
# Default Values
# ===========================================

# Default application port inside container
DEFAULT_PORT="8000"

# Default git branch to deploy
DEFAULT_BRANCH="main"

