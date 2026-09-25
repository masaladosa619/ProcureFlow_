#!/bin/sh
# Railway entrypoint for the API service.
# Runs migrations against the database, optionally seeds, then starts uvicorn.

set -e

echo "==> Running database migrations..."
python -m alembic upgrade head

# Seed the database on first deploy (only if SEED_ON_DEPLOY=true)
if [ "$SEED_ON_DEPLOY" = "true" ]; then
    echo "==> Seeding database with demo data..."
    python -m scripts.seed
fi

echo "==> Starting uvicorn on port ${PORT:-8080}..."
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8080}"
