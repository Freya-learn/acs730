#!/usr/bin/env bash
set -euo pipefail

APP_USER=acs730web
APP_HOME=/opt/acs730-web
WEB_ROOT="$APP_HOME/www"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_SRC="$SCRIPT_DIR/../acs730-web.service"

# 1. packages (package manager, not manual downloads)
sudo dnf install -y python3

# 2. service user (skip if it already exists)
id "$APP_USER" &>/dev/null || \
  sudo useradd --system --home-dir "$APP_HOME" --create-home --shell /sbin/nologin "$APP_USER"

# 3. web root owned by the service user
sudo install -d -o "$APP_USER" -g "$APP_USER" -m 755 "$WEB_ROOT"

# 4. index.html, installed with the right owner in one step
TMP="$(mktemp)"
cat > "$TMP" <<HTML
<!doctype html>
<html><body><h1>ACS730 Lab 2</h1><p>Served by systemd on $(hostname)</p></body></html>
HTML
sudo install -o "$APP_USER" -g "$APP_USER" -m 644 "$TMP" "$WEB_ROOT/index.html"
rm -f "$TMP"

# 5. systemd unit
sudo install -o root -g root -m 644 "$UNIT_SRC" /etc/systemd/system/acs730-web.service
sudo systemctl daemon-reload
sudo systemctl enable acs730-web.service     # runs after reboot
sudo systemctl restart acs730-web.service    # runs now (also picks up changes on re-run)

# 6. quick check
sleep 1
systemctl is-enabled acs730-web.service
systemctl is-active acs730-web.service
curl -s http://localhost/
