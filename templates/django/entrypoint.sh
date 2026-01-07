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

