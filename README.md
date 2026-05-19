# Symfony Docker Deployment (Railway & Other Hosting Platforms)

This project demonstrates how to containerize and deploy a Symfony application using Docker, Nginx, PHP-FPM, and MySQL.

## Quick start (run locally)

From the **project root** (`platform-deployment-final-project`):

```bash
docker compose up -d --build
```

**PowerShell (Windows):**

```powershell
cd d:\DAYANAN_PlatformFinal\platform-deployment-final-project
docker compose up -d --build
```

Or run the helper script:

```powershell
.\docker-up.ps1
```

Or with Make:

```bash
make up
```

Open [http://localhost:8080](http://localhost:8080) when containers are running.

> **Note:** Use `-d` (detached). `docker compose up d` without the hyphen is invalid.

Stop the stack:

```bash
docker compose down
```

## Technologies Used

- **Docker** — application image and repeatable builds
- **Nginx** — HTTP front controller and static assets
- **PHP-FPM** — Symfony runtime
- **MySQL 8** — persistent data store
- **Docker Compose** — local multi-container stack

## Application Features

- Symfony 7.4 with Doctrine ORM
- Product CRUD (`/product`) for database integration proof
- Home dashboard (`/`) with live database connectivity check
- Production cache warmup and migrations on container start

---

## Project Structure (Deployment Files)

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage production image (Composer build + PHP-FPM/Nginx runtime) |
| `docker-compose.yaml` | Local `app` + `database` stack |
| `Makefile` / `docker-up.ps1` | Shortcuts for `docker compose up -d --build` |
| `entrypoint.sh` | DB wait, migrations, cache warmup, start PHP-FPM + Nginx |
| `nginx.conf` | Server block (Symfony front controller, PHP-FPM) |
| `nginx-main.conf` | Global Nginx `http` settings |
| `.dockerignore` | Excludes `vendor/`, `var/`, tests from build context |
| `.env` | Local defaults; production secrets go in platform env vars |

---

## Environment Variables

| Variable | Description | Example (local) |
|----------|-------------|-----------------|
| `APP_ENV` | Symfony environment | `prod` in Docker |
| `APP_DEBUG` | Debug mode | `0` in production |
| `APP_SECRET` | Symfony secret key | Random 32+ char string |
| `DATABASE_URL` | Doctrine connection | Set by Compose or Railway MySQL |
| `MYSQL_*` | MySQL credentials (Compose) | See `.env` |
| `PORT` | HTTP listen port (Railway injects this) | `80` locally, dynamic on Railway |
| `APP_PORT` | Host port mapped to app container | `8080` |

**Security:** Do not commit real production secrets. Set `APP_SECRET` and database credentials in Railway (or your host) dashboard.

---

## Local Development with Docker Compose

### Prerequisites

- Docker Desktop (or Docker Engine + Compose v2)
- Git

### 1. Configure environment

Copy defaults in `.env` or create `.env.local` overrides:

```env
APP_SECRET=your-local-secret-at-least-32-chars
MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=symfony
MYSQL_USER=symfony
MYSQL_PASSWORD=symfony
```

### 2. Build and start (detached)

```bash
docker compose up -d --build
```

Equivalent options:

```bash
make up
# or
.\docker-up.ps1
```

### 3. Verify

- Application: [http://localhost:8080](http://localhost:8080)
- Products CRUD: [http://localhost:8080/product](http://localhost:8080/product)
- MySQL (host): `127.0.0.1:3310`

The entrypoint runs migrations automatically. You should see **Database connection is working** on the home page.

### 4. Stop

```bash
docker compose down
```

To remove the database volume:

```bash
docker compose down -v
```

---

## How the Container Works

### Dockerfile (high level)

1. **Composer stage** — installs production dependencies, compiles `.env` for prod, warms cache, compiles asset map.
2. **Runtime stage** — PHP 8.3-FPM, Nginx, extensions (`pdo_mysql`, `intl`, `zip`, `opcache`), copies the built app.

### Nginx

- `nginx-main.conf` — worker and `http` block; includes `conf.d/*.conf`.
- `nginx.conf` — Symfony `public/` root, `try_files` → `index.php`, FastCGI to `127.0.0.1:9000`.
- At startup, `entrypoint.sh` substitutes `${PORT}` so Railway can bind the platform port.

### entrypoint.sh

1. Render Nginx config with `PORT`
2. Wait for database (up to 60 seconds)
3. Run Doctrine migrations
4. Warm prod cache (if `APP_ENV=prod`)
5. Start PHP-FPM and Nginx

---

## Deploy to Railway

### Prerequisites

- [Railway](https://railway.app) account
- GitHub repository with this project

### Steps

1. **Push** the project to GitHub.

2. **New project** → Deploy from GitHub repo → select this repository.

3. **Add MySQL** — in the project, click **+ New** → **Database** → **MySQL**. Railway provides `MYSQL_URL` / connection variables.

4. **Configure the web service** environment variables:

   | Variable | Value |
   |----------|--------|
   | `APP_ENV` | `prod` |
   | `APP_DEBUG` | `0` |
   | `APP_SECRET` | Strong random string |
   | `DATABASE_URL` | Use Railway MySQL reference, e.g. `${{MySQL.MYSQL_URL}}` or the provided JDBC-style URL converted to Doctrine format: `mysql://user:pass@host:port/db?serverVersion=8.0.32&charset=utf8mb4` |

   Railway automatically sets `PORT`; the entrypoint configures Nginx to listen on it.

5. **Deploy** — Railway builds from the root `Dockerfile`. Open the generated public URL.

6. **Verify** — Home page shows deployment success and working DB; test `/product` CRUD.

### Railway tips

- Use **Variables** → **Reference** to link MySQL credentials from the database service.
- Check **Deploy Logs** if migrations fail (usually DB not linked or wrong `DATABASE_URL`).
- Redeploy after changing environment variables.

---

## Symfony Production Checklist

- [x] `APP_ENV=prod` and `APP_DEBUG=0` in deployment
- [x] Opcache enabled in Docker image
- [x] `composer dump-env prod` during image build
- [x] Cache warmup in build and entrypoint
- [x] Migrations on startup
- [x] Nginx denies direct access to arbitrary `.php` files

---

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| Database connection failed | `DATABASE_URL`, MySQL service running, Railway variable references |
| 502 / blank page | Deploy logs; PHP-FPM started; `var/` permissions |
| Migrations fail | DB reachable from app; credentials; empty vs existing schema |
| Assets missing | Rebuild image (`asset-map:compile` runs in Dockerfile) |

---

## What to Submit (Course)

- Link to your live deployed application
- **5–10 minute video** covering:
  - Dockerfile setup (1–2 min)
  - Nginx configuration (1–2 min)
  - Environment variables (1 min)
  - Deployment walkthrough (2–3 min)
  - Proof the live app works (1–2 min)

## Grading Rubric (Total: 100 Points)

| Category | Points |
|----------|--------|
| Docker Setup | 25 |
| Nginx Configuration | 15 |
| Symfony Production Setup | 15 |
| Environment & Security | 10 |
| Database Integration | 10 |
| Deployment | 15 |
| Understanding (Video) | 7 |
| Video Presentation Quality | 3 |

---

## Notes

This project is intended for educational purposes and demonstrates full-stack containerized deployment practices using Symfony.
