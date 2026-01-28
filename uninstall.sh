#!/usr/bin/env bash
set -euo pipefail

echo "[uninstall] Stopping + disabling service…"
sudo systemctl stop geoPi.service 2>/dev/null || true
sudo systemctl disable geoPi.service 2>/dev/null || true
sudo systemctl daemon-reload

echo "[uninstall] Removing files…"
sudo rm -f /etc/systemd/system/geoPi.service
sudo rm -f /usr/local/bin/geoPi_agent.sh
sudo rm -f /usr/local/bin/geoPi-location

# Keep profiles unless --purge
if [[ "${1:-}" == "--purge" ]]; then
  sudo rm -f /etc/geoPi.env
  sudo rm -rf /etc/geoPi
  sudo rm -f /var/log/geoPi_tunneld.log
  echo "[uninstall] Purged profiles and logs."
else
  echo "[uninstall] Left /etc/geoPi{.env,/locations} and /var/log/geoPi_tunneld.log in place."
fi

echo "[uninstall] Done."
