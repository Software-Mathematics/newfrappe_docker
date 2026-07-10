# SMERP deploy assets

Server-side files used by the Jenkins `smerp` pipeline
(`jobTemplates/SmerpDeployment.groovy` in the Kubernetes-manifest-files repo).

| File | Role |
|---|---|
| `build-deploy.sh` | Runs on the VM: build the image, `up -d`, install apps, nginx + TLS |
| `smerp.prod.yml` | Compose stack using the locally-built `smerp:latest` image |
| `nginx/erp.softwaremathematics.com.conf` | Host nginx vhost proxying `:8080` (certbot adds TLS) |

## Why the build runs on the VM

The Jenkins here is **Kaniko-only** (no Docker daemon), and the frappe layered
`Containerfile` uses `RUN --mount=type=secret` (a BuildKit feature Kaniko can't
do). So Jenkins can't build this image. The VM already runs Docker for the
compose stack, so the image is built there — the RUNBOOK flow, automated.

## Pipeline flow

1. Jenkins `smerp` job (in the `ansible` container) SSHes to the VM using the
   `smerp-server-cred` username/password credential (`sshpass`).
2. On the VM it clones/updates this repo, then runs `deploy/build-deploy.sh`,
   which:
   - `docker build` base (SMERP fork + healthcare on frappe `version-15`) →
     `fix-crlf` → `theme` layers, tagged `smerp:latest`
   - `docker compose -f smerp.prod.yml -p smerp up -d`
   - installs `healthcare` + `smerp_theme`, runs `migrate`
   - installs the nginx vhost and obtains/renews the Let's Encrypt cert

No Nexus and no image push are involved — the image stays local on the VM.

## One-time prerequisites on the VM (79.143.176.226)

- Docker Engine + Compose v2, `git`, `nginx`, `certbot` (+ `python3-certbot-nginx`).
- The SSH user (`deploy_user`, default `root`) reachable with the password
  stored in `smerp-server-cred`; if not root, it needs passwordless `sudo`.
- DNS `A` record `erp.softwaremathematics.com -> 79.143.176.226`; ports 80/443 open.
- If `newfrappe_docker.git` is **private**, give the VM read access (deploy key
  or a token in the clone URL) so the `git clone` step works.
- If `NewSMERP.git` is **private**, add a token to its URL in `apps.json` so the
  image build's `bench get-app` can clone it.

## Notes

- Default site is `frontend` with `FRAPPE_SITE_NAME_HEADER=frontend`, so the
  stack serves regardless of the incoming `Host`; nginx just proxies.
- `create-site` skips if the site already exists, so redeploys preserve data
  (named volumes `db-data`, `sites`, `logs`).
- Default credentials (`admin`) and DB password come from the demo compose —
  change them before treating this as production.
- To run the whole thing by hand on the VM:
  `FRAPPE_BRANCH=version-15 DOMAIN=erp.softwaremathematics.com bash deploy/build-deploy.sh`
