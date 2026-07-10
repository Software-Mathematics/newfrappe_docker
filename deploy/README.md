# SMERP deploy assets

Server-side files used by the Jenkins `smerp` pipeline
(`jobTemplates/SmerpDeployment.groovy` in the Kubernetes-manifest-files repo).

| File | Role |
|---|---|
| `smerp.prod.yml` | Compose stack using the Nexus image; frontend bound to `127.0.0.1:8080` |
| `nginx/erp.softwaremathematics.com.conf` | Host nginx vhost proxying `:8080` (certbot adds TLS) |
| `deploy.sh` | Runs on the VM: pull image, `up -d`, install apps, wire nginx + TLS |

## Pipeline flow

1. **Build** — from this repo's `images/layered/Containerfile` + `apps.json`
   (SMERP fork + healthcare on frappe `version-15`), then the `fix-crlf` and
   `theme` patch layers → tag `nexus.softwaremathematics.com/smerp:<BUILD_TIMESTAMP>`.
2. **Push** to Nexus (`:BUILD_TIMESTAMP` and `:latest`).
3. **Deploy** (approval-gated) — `scp` these files to `/opt/smerp` on
   `79.143.176.226` and run `deploy.sh`.

## One-time prerequisites on the VM (79.143.176.226)

- Docker Engine + Compose v2, `nginx`, `certbot` (+ `python3-certbot-nginx`).
- The `deploy_user` (default `root`) must reach the registry and, if not root,
  have **passwordless sudo** for `nginx`/`certbot`/`cp`.
- Jenkins SSH key (`private-key` credential) authorised for that user.
- DNS `A` record `erp.softwaremathematics.com -> 79.143.176.226`.
- Port 80 + 443 open (certbot HTTP-01 challenge + serving).

## Notes

- Default site is `frontend` with `FRAPPE_SITE_NAME_HEADER=frontend`, so the
  stack serves regardless of the incoming `Host`; nginx just proxies.
- `create-site` is guarded to skip if the site already exists, so redeploys are
  safe and preserve data (named volumes `db-data`, `sites`, `logs`).
- **Private app repo:** if `NewSMERP.git` is private, add a token to the URL in
  `apps.json` (e.g. `https://<PAT>@github.com/Software-Mathematics/NewSMERP.git`)
  so `bench get-app` can clone it during the image build.
- Default credentials (`admin`) and DB password are inherited from the demo
  compose — change them before treating this as production.
