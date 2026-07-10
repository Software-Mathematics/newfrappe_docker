#!/usr/bin/env bash
# Build the SMERP image on THIS host (needs a real Docker daemon) and (re)deploy
# the compose stack behind host nginx + certbot TLS. This is the RUNBOOK build,
# automated — the Jenkins 'smerp' job runs it over SSH on the target VM.
#
# Run from the frappe_docker repo root on the VM:
#   FRAPPE_BRANCH=version-15 DOMAIN=erp.softwaremathematics.com \
#   CACHE_BUST=$(date +%s) bash deploy/build-deploy.sh
set -euo pipefail

FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-15}"
DOMAIN="${DOMAIN:?DOMAIN is required}"
CACHE_BUST="${CACHE_BUST:-$(date +%s)}"
IMAGE="smerp:latest"

# Non-root sudo user (e.g. devops): use sudo for docker if the daemon isn't
# reachable directly, and for privileged host commands (nginx/certbot).
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"
USE_SUDO=0
docker info >/dev/null 2>&1 || USE_SUDO=1

# docker wrapper: enables BuildKit and adds sudo only when needed. Passing
# DOCKER_BUILDKIT on sudo's command line survives env_reset (unlike `sudo -E`).
d() {
  if [ "$USE_SUDO" = "1" ]; then sudo DOCKER_BUILDKIT=1 docker "$@"
  else DOCKER_BUILDKIT=1 docker "$@"; fi
}
dc() { d compose -f smerp.prod.yml -p smerp "$@"; }

echo ">> [1/5] Building base image ($IMAGE) on frappe $FRAPPE_BRANCH"
d build \
  --build-arg FRAPPE_BRANCH="$FRAPPE_BRANCH" \
  --build-arg CACHE_BUST="$CACHE_BUST" \
  --secret id=apps_json,src=apps.json \
  -t "$IMAGE" -f images/layered/Containerfile .

echo ">> [2/5] Applying CRLF fix + theme layers"
d build -f fix-crlf.Dockerfile -t "$IMAGE" .
d build -f theme.Dockerfile   -t "$IMAGE" .

echo ">> [3/5] Starting the compose stack"
cd deploy
export SMERP_IMAGE="$IMAGE"
dc up -d

echo ">> [4/5] Waiting for create-site to finish (first run installs erpnext; can take 10-20 min)"
CS_ID=$(dc ps -aq create-site 2>/dev/null | head -1)
if [ -n "$CS_ID" ]; then
  for i in $(seq 1 240); do          # up to ~40 min
    st=$(d inspect -f '{{.State.Status}}' "$CS_ID" 2>/dev/null || echo unknown)
    if [ "$st" = "exited" ]; then
      code=$(d inspect -f '{{.State.ExitCode}}' "$CS_ID" 2>/dev/null || echo 1)
      [ "$code" = "0" ] && { echo "   create-site completed"; break; }
      echo "   create-site FAILED (exit $code) — recent logs:"; dc logs --tail 60 create-site || true
      exit 1
    fi
    sleep 10
    if [ "$i" -eq 240 ]; then
      echo "   create-site still running after 40 min — recent logs:"; dc logs --tail 60 create-site || true
      exit 1
    fi
  done
fi

echo ">> Confirming the site is reachable from backend"
for i in $(seq 1 24); do
  dc exec -T backend bench --site frontend list-apps >/dev/null 2>&1 && break
  sleep 5
done

echo ">> Ensuring extra apps installed (healthcare, smerp_theme)"
installed=$(dc exec -T backend bench --site frontend list-apps 2>/dev/null || true)
for app in healthcare smerp_theme; do
  if ! grep -qw "$app" <<<"$installed"; then
    echo "   installing $app"
    dc exec -T backend bench --site frontend install-app "$app" || true
  fi
done
dc exec -T backend bench --site frontend migrate || true

echo ">> [5/5] Configuring host nginx + TLS for $DOMAIN"
$SUDO cp nginx/erp.softwaremathematics.com.conf /etc/nginx/sites-available/erp.softwaremathematics.com.conf
$SUDO ln -sf /etc/nginx/sites-available/erp.softwaremathematics.com.conf \
             /etc/nginx/sites-enabled/erp.softwaremathematics.com.conf
$SUDO nginx -t
$SUDO systemctl reload nginx
if $SUDO test -d "/etc/letsencrypt/live/$DOMAIN"; then
  echo "   certificate already present for $DOMAIN"
elif $SUDO certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos \
        -m admin@softwaremathematics.com --redirect; then
  echo "   certbot issued a certificate for $DOMAIN"
else
  echo "   WARNING: certbot could not issue a cert (domain proxied via Cloudflare?)." >&2
  echo "   Stack is up on :8080 (HTTP). Handle TLS at Cloudflare or grey-cloud + re-run." >&2
fi

echo ">> Done. SMERP backend is up. Public URL: https://$DOMAIN (via your edge/TLS)"
