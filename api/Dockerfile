FROM python:3.12-slim AS base

# Prevents Python from writing .pyc files and enables unbuffered stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies needed by psycopg (binary) and general build
RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies first (layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Railway injects PORT as an env var (defaults to 8080 if not set)
ENV PORT=8080

# Expose the port
EXPOSE ${PORT}

# Start script: run migrations then start the server
RUN chmod +x start.sh
CMD ["./start.sh"]
