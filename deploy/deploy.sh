#!/usr/bin/env bash
# Server-side SMERP deploy, run by the Jenkins pipeline over SSH from ${remote_dir}.
# Pulls the Nexus image, (re)starts the compose stack, ensures healthcare +
# smerp_theme are installed on the site, then wires up host nginx + TLS.
#
# Required env (passed by the pipeline):
#   SMERP_IMAGE  nexus.softwaremathematics.com/smerp:<tag>
#   DOMAIN       erp.softwaremathematics.com
#   NEXUS_USER / NEXUS_PSW   Nexus docker registry creds
set -euo pipefail

: "${SMERP_IMAGE:?SMERP_IMAGE is required}"
: "${DOMAIN:?DOMAIN is required}"
: "${NEXUS_USER:?NEXUS_USER is required}"
: "${NEXUS_PSW:?NEXUS_PSW is required}"

REGISTRY="nexus.softwaremathematics.com"
COMPOSE=(docker compose -f smerp.prod.yml -p smerp)
export SMERP_IMAGE

echo ">> Logging in to $REGISTRY"
echo "$NEXUS_PSW" | docker login -u "$NEXUS_USER" --password-stdin "$REGISTRY"

echo ">> Pulling $SMERP_IMAGE and starting the stack"
"${COMPOSE[@]}" pull
"${COMPOSE[@]}" up -d

echo ">> Waiting for site 'frontend' to be ready"
for i in $(seq 1 60); do
  if "${COMPOSE[@]}" exec -T backend bench --site frontend list-apps >/dev/null 2>&1; then
    break
  fi
  sleep 5
  [[ $i -eq 60 ]] && { echo "site did not come up in time"; exit 1; }
done

echo ">> Ensuring extra apps are installed"
installed=$("${COMPOSE[@]}" exec -T backend bench --site frontend list-apps 2>/dev/null || true)
for app in healthcare smerp_theme; do
  if ! grep -qw "$app" <<<"$installed"; then
    echo "   installing $app"
    "${COMPOSE[@]}" exec -T backend bench --site frontend install-app "$app" || true
  else
    echo "   $app already installed"
  fi
done
"${COMPOSE[@]}" exec -T backend bench --site frontend migrate || true

echo ">> Configuring host nginx for $DOMAIN"
sudo cp nginx/erp.softwaremathematics.com.conf /etc/nginx/sites-available/erp.softwaremathematics.com.conf
sudo ln -sf /etc/nginx/sites-available/erp.softwaremathematics.com.conf \
            /etc/nginx/sites-enabled/erp.softwaremathematics.com.conf
sudo nginx -t
sudo systemctl reload nginx

echo ">> Ensuring TLS certificate"
if ! sudo test -d "/etc/letsencrypt/live/$DOMAIN"; then
  sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos \
       -m admin@softwaremathematics.com --redirect
else
  echo "   certificate already present for $DOMAIN"
fi

echo ">> Done. SMERP is live at https://$DOMAIN"
