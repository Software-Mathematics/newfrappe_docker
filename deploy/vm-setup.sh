#!/usr/bin/env bash
# One-time provisioning for the SMERP VM (Debian/Ubuntu).
# Installs Docker Engine + Compose plugin, git, nginx, certbot, and opens
# ports 80/443/22. Run ONCE as root on the target VM:
#   bash vm-setup.sh
#
# DNS is NOT handled here — create an A record at your DNS provider:
#   erp.softwaremathematics.com  ->  79.143.176.226
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root (or: sudo bash vm-setup.sh)"; exit 1
fi

export DEBIAN_FRONTEND=noninteractive
. /etc/os-release   # provides $ID (ubuntu/debian) and $VERSION_CODENAME

echo ">> [1/4] Base tools (git, nginx, certbot, ufw)"
apt-get update
apt-get install -y ca-certificates curl gnupg git nginx certbot python3-certbot-nginx ufw

echo ">> [2/4] Docker Engine + Compose plugin"
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker
systemctl enable --now nginx

echo ">> [3/4] Firewall (open 22/80/443 if ufw is in use)"
if command -v ufw >/dev/null 2>&1; then
  ufw allow 22/tcp  || true
  ufw allow 80/tcp  || true
  ufw allow 443/tcp || true
fi

echo ">> [4/4] Versions"
docker --version
docker compose version
git --version
nginx -v
certbot --version || true

echo ""
echo "VM provisioning complete."
echo "Remaining manual step: point DNS  erp.softwaremathematics.com -> 79.143.176.226"
