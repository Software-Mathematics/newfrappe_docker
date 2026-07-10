# SMERP — Docker Runbook

Running the SMERP ERP (your ERPNext fork) locally with Docker on Windows.

- **URL:** http://localhost:8080
- **Username:** `Administrator`
- **Password:** `admin`
- **Project folder:** `C:\SMERP\frappe_docker`
- **Stack:** SMERP fork (develop) on Frappe **version-15** (15.113.4), MariaDB 10.6, Redis 6.2
- **Installed apps:** frappe, erpnext (SMERP), **healthcare 15.2.0**

---

## Everyday use — start & stop

Open a terminal, go to the project folder, then use these. Prefer `stop`/`start`
over `down`/`up` for daily use — they keep the containers and are faster.

```powershell
cd C:\SMERP\frappe_docker

# START (ready at localhost:8080 after ~20s)
docker compose -f smerp.yml start

# STOP (all data preserved)
docker compose -f smerp.yml stop

# STATUS — every row should say "Up"
docker compose -f smerp.yml ps

# LOGS — follow a service live
docker compose -f smerp.yml logs -f backend
```

### Stopped vs. removed vs. wiped
| Command | Effect |
|---|---|
| `stop` | Pauses containers. Fastest to resume with `start`. |
| `down` | Removes containers but **keeps** the data volume. Next `up -d` recreates them; your site is still there. |
| `down -v` | Removes containers **and deletes the database/site**. Use only for a clean slate. |

```powershell
# FULL RESET (wipes site + DB, keeps the built image, recreates site)
docker compose -f smerp.yml down -v
docker compose -f smerp.yml up -d
```

---

## How it was built (one time)

Already done. Only repeat if you delete the `smerp:latest` image or move machines.

1. **Docker CLI on PATH** — Docker Desktop installed per-user; its bin was added to your
   user PATH: `C:\Users\103fa\AppData\Local\Programs\DockerDesktop\resources\bin`

2. **Get build tooling**
   ```powershell
   git clone --depth 1 https://github.com/frappe/frappe_docker C:\SMERP\frappe_docker
   ```

3. **apps.json** — points the build at your fork (`C:\SMERP\frappe_docker\apps.json`):
   ```json
   [
     { "url": "https://github.com/Software-Mathematics/SMERP.git", "branch": "develop" }
   ]
   ```

4. **Build the image on frappe version-15** (~15–25 min):
   ```powershell
   cd C:\SMERP\frappe_docker
   docker build `
     --build-arg FRAPPE_BRANCH=version-15 `
     --secret id=apps_json,src=apps.json `
     --tag smerp:latest `
     --file images/layered/Containerfile .
   ```

5. **Fix Windows CRLF in entrypoint** (thin patch layer):
   ```powershell
   docker build -f fix-crlf.Dockerfile -t smerp:latest .
   ```

6. **Start & create the site:**
   ```powershell
   docker compose -f smerp.yml up -d
   # the one-shot create-site job builds the DB and installs erpnext,
   # reaches "Updating DocTypes ... 100%", then the app is live.
   ```

---

## Three problems that were solved

1. **Docker CLI not recognized** — per-user install wasn't on PATH → added `resources\bin`.
2. **Wrong framework version (the big one)** — the fork (frozen May 2023) needs frappe
   **version-15** features: redis-py 4.x (e-commerce search) and `is_last_day_of_the_month`
   (asset depreciation). Building on version-14 caused cascading import errors → rebuilt on
   frappe version-15.
3. **Containers crash-looping** — entrypoint scripts had CRLF line endings; Linux reported
   `no such file or directory` on the `#!/bin/bash` line → `fix-crlf.Dockerfile` strips the CRs.

---

## Files in this folder

| File | Purpose |
|---|---|
| `smerp.yml` | Compose file — 9 services (backend, frontend, db, redis ×2, workers ×2, scheduler, websocket) |
| `apps.json` | Bakes your SMERP fork (develop) into the image |
| `fix-crlf.Dockerfile` | Patch layer fixing Windows line endings in the entrypoint |
| `images/layered/Containerfile` | Stock frappe_docker recipe for the base image |
| `RUNBOOK.md` | This document |

---

## Adding another app (how healthcare was added)

In Docker, apps are **baked into the image**, so `bench get-app` is replaced by
"add to apps.json + rebuild". The `bench --site ... install-app` step is the same.

1. Add the app to `apps.json` (pick the branch matching frappe version-15):
   ```json
   { "url": "https://github.com/frappe/healthcare.git", "branch": "version-15" }
   ```
2. Rebuild — **must** pass a new `CACHE_BUST` or Docker reuses the cached
   `bench init` layer and the new app won't be baked in:
   ```powershell
   docker build --build-arg FRAPPE_BRANCH=version-15 --build-arg CACHE_BUST=healthcare-v1 `
     --secret id=apps_json,src=apps.json --tag smerp:latest --file images/layered/Containerfile .
   docker build -f fix-crlf.Dockerfile -t smerp:latest .   # re-apply CRLF fix
   ```
3. Recreate containers on the new image (keeps data):
   ```powershell
   docker compose -f smerp.yml up -d --force-recreate backend frontend queue-long queue-short scheduler websocket configurator
   ```
4. Install on the site:
   ```powershell
   docker exec frappe_docker-backend-1 bash -lc "cd /home/frappe/frappe-bench && bench --site frontend install-app healthcare"
   ```

> **Tip:** install-app on a **clean** site is the most reliable. A failed/partial
> install can leave a `Module Def` behind that blocks retries with a duplicate-key
> error — if that happens, `down -v` + `up -d` for a fresh site, then install again.

---

## Troubleshooting

| Symptom | Do this |
|---|---|
| Page won't load | Ensure **Docker Desktop** is running, then `docker compose -f smerp.yml ps` — all "Up" |
| Container says *Restarting* | `docker compose -f smerp.yml logs backend` |
| `docker` not found | Open a **new** terminal (PATH change only applies to fresh windows) |
| Want a clean slate | `docker compose -f smerp.yml down -v` then `up -d` |
| Port 8080 in use | Edit the `ports:` line under `frontend` in `smerp.yml`, e.g. `"9090:8080"` |

> **Note:** This is a development setup — default `admin` password and dev config. Great for
> running and exploring locally, not hardened for production or public exposure.
