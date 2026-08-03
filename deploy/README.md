# SMERP deploy assets

Server-side files used by the Jenkins SMERP pipelines
(`jobTemplates/SmerpDeployment.groovy` in the Kubernetes-manifest-files repo).

| File | Role |
|---|---|
| `build-deploy.sh` | Runs on the VM: build the image, `up -d`, install apps, nginx + TLS |
| `smerp.prod.yml` | Compose stack using the locally-built `smerp:latest` image |
| `nginx/smerp.conf.template` | Host nginx vhost template, rendered per domain (certbot adds TLS) |
| `vm-setup.sh` | One-time VM provisioning (Docker, nginx, certbot, firewall) |

Nothing here is host-specific — every deployment passes its own environment, so
the same assets serve every SMERP instance.

## Deployments

| Jenkins job | VM | Domain | SSH user / dir | Credential |
|---|---|---|---|---|
| `SoftwareMathematics/erp/SMERP/smerp` | 79.143.176.226 | erp.softwaremathematics.com | `devops` / `/home/devops/smerp` | `smerp-server-cred` |
| `SoftwareMathematics/erp/MedharvaERP/medharva-erp` | 169.58.105.60 | erp.medharva.com | `root` / `/opt/smerp` | `medharva-erp-server-cred` |

## Why the build runs on the VM

The Jenkins here is **Kaniko-only** (no Docker daemon), and the frappe layered
`Containerfile` uses `RUN --mount=type=secret` (a BuildKit feature Kaniko can't
do). So Jenkins can't build this image. The VM already runs Docker for the
compose stack, so the image is built there — the RUNBOOK flow, automated.

## Pipeline flow

1. The Jenkins job (in the `ansible` container) SSHes to its VM using the
   username/password credential named in the pipeline YAML (`sshpass`).
2. On the VM it clones/updates this repo, then runs `deploy/build-deploy.sh`,
   which:
   - `docker build` base (SMERP fork + healthcare on frappe `version-15`) →
     `fix-crlf` → `theme` layers, tagged `smerp:latest`
   - `docker compose -f smerp.prod.yml -p $COMPOSE_PROJECT up -d`
   - installs `healthcare` + `smerp_theme`, runs `migrate`
   - renders the nginx vhost (first deploy only) and obtains the Let's Encrypt cert

No Nexus and no image push are involved — the image stays local on the VM.

## Environment consumed by `build-deploy.sh`

| Var | Default | Meaning |
|---|---|---|
| `DOMAIN` | *(required)* | Public hostname; drives the vhost filename and the cert |
| `FRAPPE_BRANCH` | `version-15` | Frappe branch the image is built from |
| `CERTBOT_EMAIL` | `admin@softwaremathematics.com` | Let's Encrypt registration address |
| `COMPOSE_PROJECT` | `smerp` | `docker compose -p` project name |
| `HTTP_BIND_PORT` | `8080` | Host loopback port the frontend is published on |
| `CACHE_BUST` | `$(date +%s)` | Forces a fresh `bench get-app` layer |

## One-time prerequisites on a new VM

1. `DOMAIN=<domain> bash deploy/vm-setup.sh` as root — Docker Engine + Compose v2,
   `git`, `nginx`, `certbot` (+ `python3-certbot-nginx`), ports 22/80/443.
2. The SSH user (`deploy_user`) reachable with the password stored in the
   Jenkins credential; if not `root`, it needs passwordless `sudo`.
3. DNS `A` record `<domain> -> <VM IP>`, ports 80/443 reachable.
4. If `newfrappe_docker.git` is **private**, give the VM read access (deploy key
   or a token in the clone URL) so the `git clone` step works.
5. If `NewSMERP.git` is **private**, add a token to its URL in `apps.json` so the
   image build's `bench get-app` can clone it.

## Notes

- Default site is `frontend` with `FRAPPE_SITE_NAME_HEADER=frontend`, so the
  stack serves regardless of the incoming `Host`; nginx just proxies.
- `create-site` skips if the site already exists, so redeploys preserve data
  (named volumes `db-data`, `sites`, `logs`).
- The nginx vhost is written only when it does not exist yet — certbot edits it
  in place to add the `:443` block, and rewriting it on redeploy would drop TLS.
- Default credentials (`admin`) and DB password come from the demo compose —
  change them before treating this as production.
- To run the whole thing by hand on a VM:
  `FRAPPE_BRANCH=version-15 DOMAIN=erp.medharva.com CERTBOT_EMAIL=admin@medharva.com bash deploy/build-deploy.sh`
