# 🚀 ProcureFlow — Railway + Supabase Deployment Guide

## Architecture Overview

```mermaid
flowchart LR
    subgraph Railway
        FE["Frontend Service<br/>(React + Nginx)"]
        BE["Backend Service<br/>(FastAPI + Uvicorn)"]
    end
    subgraph Supabase
        DB["PostgreSQL Database"]
    end
    User -->|HTTPS| FE
    FE -->|API calls| BE
    BE -->|psycopg3| DB
```

## Files Created/Modified

| File | Purpose |
|------|---------|
| [`api/Dockerfile`](file:///home/masaladosa/ProcureFlow_/api/Dockerfile) | Backend container — Python 3.12, installs deps, runs migrations on startup |
| [`api/.dockerignore`](file:///home/masaladosa/ProcureFlow_/api/.dockerignore) | Keeps backend image small |
| [`api/start.sh`](file:///home/masaladosa/ProcureFlow_/api/start.sh) | Entrypoint: migrations → optional seed → uvicorn |
| [`api/.env.production.example`](file:///home/masaladosa/ProcureFlow_/api/.env.production.example) | Reference for Railway env vars (backend) |
| [`web/Dockerfile`](file:///home/masaladosa/ProcureFlow_/web/Dockerfile) | Frontend container — multi-stage build → nginx |
| [`web/nginx.conf`](file:///home/masaladosa/ProcureFlow_/web/nginx.conf) | SPA routing + gzip + asset caching |
| [`web/.dockerignore`](file:///home/masaladosa/ProcureFlow_/web/.dockerignore) | Keeps frontend image small |
| [`web/.env.production.example`](file:///home/masaladosa/ProcureFlow_/web/.env.production.example) | Reference for Railway env vars (frontend) |
| [`api/app/main.py`](file:///home/masaladosa/ProcureFlow_/api/app/main.py#L27) | Updated CORS regex to include `*.up.railway.app` |
| [`.gitignore`](file:///home/masaladosa/ProcureFlow_/.gitignore) | Added exceptions for `.env.production.example` files |

---

## Step-by-Step Deployment

### Step 1: Set Up Supabase Database

1. Go to [supabase.com](https://supabase.com) → **New Project**
2. Choose a region close to your Railway region (e.g., `ap-south-1` Mumbai)
3. Set a strong database password — **save it**
4. Once the project is created, go to **Settings → Database → Connection string**
5. Copy the **URI** tab connection string (port `5432`). It looks like:
   ```
   postgresql://postgres.abcxyz:YOUR-PASSWORD@aws-0-ap-south-1.pooler.supabase.com:5432/postgres
   ```

> [!IMPORTANT]
> Use the **Session mode** connection string (port `5432`), NOT the Transaction pooler (port `6543`). SQLAlchemy needs session-level connections for migrations and ORM features.

---

### Step 2: Deploy the Backend on Railway

1. Go to [railway.app](https://railway.app) → **New Project → Deploy from GitHub repo**
2. Select your `ProcureFlow_` repository
3. Railway will auto-detect the repo. Click **Add a Service** and configure:

   **Service settings:**
   - **Name:** `procureflow-api`
   - **Root Directory:** `api`
   - **Builder:** Dockerfile (auto-detected from `api/Dockerfile`)

4. **Set these environment variables** in the Railway service settings:

   | Variable | Value |
   |----------|-------|
   | `DATABASE_URL` | Your Supabase connection string from Step 1 |
   | `JWT_SECRET` | A strong random string (e.g., `openssl rand -hex 32`) |
   | `JWT_ALGORITHM` | `HS256` |
   | `JWT_EXPIRE_MINUTES` | `720` |
   | `DEMO_PASSWORD` | `demo1234` (or your preferred demo password) |
   | `CORS_ORIGINS` | *(leave empty for now, set after deploying frontend)* |
   | `SEED_ON_DEPLOY` | `true` *(set this for the FIRST deploy only!)* |

5. Click **Deploy** and wait for the build to complete
6. Once deployed, go to **Settings → Networking → Generate Domain**
7. Note the URL (e.g., `https://procureflow-api-production.up.railway.app`)

> [!WARNING]
> After the first successful deploy with seeded data, go back and change `SEED_ON_DEPLOY` to `false` (or remove it). Otherwise the seed script will run on every redeploy, which may cause errors since the data already exists.

---

### Step 3: Deploy the Frontend on Railway

1. In the same Railway project, click **+ New → Service → GitHub Repo** (same repo)
2. Configure:

   **Service settings:**
   - **Name:** `procureflow-web`
   - **Root Directory:** `web`
   - **Builder:** Dockerfile (auto-detected from `web/Dockerfile`)

3. **Set these environment variables:**

   | Variable | Value |
   |----------|-------|
   | `VITE_API_URL` | Your backend URL from Step 2 (e.g., `https://procureflow-api-production.up.railway.app`) |

> [!IMPORTANT]
> `VITE_API_URL` is a **build-time** variable (baked into the JS bundle by Vite). It must be set **before** the build runs. If you change it, you need to **redeploy** the frontend.

4. Click **Deploy** and wait for the build
5. Go to **Settings → Networking → Generate Domain**
6. Note the URL (e.g., `https://procureflow-web-production.up.railway.app`)

---

### Step 4: Connect CORS (Backend ↔ Frontend)

Go back to your **backend service** on Railway and update:

| Variable | Value |
|----------|-------|
| `CORS_ORIGINS` | Your frontend URL (e.g., `https://procureflow-web-production.up.railway.app`) |

This triggers a redeploy of the backend with the correct CORS settings.

> [!TIP]
> The CORS regex in [`main.py`](file:///home/masaladosa/ProcureFlow_/api/app/main.py#L27) already allows `*.up.railway.app` domains as a fallback, so even without setting `CORS_ORIGINS`, it should work. But setting it explicitly is best practice.

---

### Step 5: Verify the Deployment

1. **Health check:** Visit `https://<your-api-url>/health` — should return `{"status": "ok", "service": "procureflow-api"}`
2. **API docs:** Visit `https://<your-api-url>/docs` — FastAPI's Swagger UI
3. **Frontend:** Visit `https://<your-web-url>` — the ProcureFlow app
4. **Login** with demo credentials:
   - Officer: `officer@mahagov.in` / `demo1234`
   - Startup: `founder@startup.in` / `demo1234`
   - Expert: `expert@evaluator.in` / `demo1234`
   - Admin: `admin@procureflow.in` / `demo1234`

---

## How It All Works

### Database URL Normalization
Your [`config.py`](file:///home/masaladosa/ProcureFlow_/api/app/config.py#L29-L37) already has a `normalize_database_url` validator that converts:
- `postgres://` → `postgresql+psycopg://`
- `postgresql://` → `postgresql+psycopg://`

This means Supabase's connection string (which starts with `postgresql://`) is automatically converted to the `postgresql+psycopg://` format that SQLAlchemy + psycopg3 expects. **No manual editing needed.**

### Migrations on Startup
The [`start.sh`](file:///home/masaladosa/ProcureFlow_/api/start.sh) script runs `alembic upgrade head` before starting the server. This ensures the database schema is always up-to-date on every deploy.

### Frontend API Configuration
[`api.ts`](file:///home/masaladosa/ProcureFlow_/web/src/lib/api.ts#L8) reads `VITE_API_URL` from the environment. Since Vite embeds env vars at build time, the Railway env var is baked into the production bundle.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| **CORS errors in browser** | Verify `CORS_ORIGINS` on the backend includes your exact frontend URL (no trailing slash) |
| **Database connection refused** | Check Supabase is using port `5432` (Session mode), not `6543` |
| **Migrations fail** | Check `DATABASE_URL` is correct; try connecting with `psql` from your machine first |
| **Frontend shows "localhost" API calls** | `VITE_API_URL` was not set before build — set it and redeploy |
| **Seed script errors on redeploy** | Set `SEED_ON_DEPLOY=false` after the first successful seed |

---

## Cost Estimate

| Service | Railway Plan | Cost |
|---------|-------------|------|
| Backend (API) | Hobby ($5/mo) | ~$5/mo |
| Frontend (Nginx) | Hobby ($5/mo) | ~$5/mo |
| Database | Supabase Free Tier | $0 |
| **Total** | | **~$10/mo** |

> [!NOTE]
> Railway's Hobby plan includes $5 of usage per service per month. For a prototype/demo, this is usually more than enough. Supabase's free tier gives you 500 MB database storage and 2 GB bandwidth, which is plenty for a hackathon prototype.
btw 