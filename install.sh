#!/usr/bin/env bash
set -euo pipefail

# Paths
UNIT_SRC="systemd/geoPi.service"
UNIT_DST="/etc/systemd/system/geoPi.service"

AGENT_SRC="bin/geoPi_agent.sh"
AGENT_DST="/usr/local/bin/geoPi_agent.sh"

SWITCH_SRC="bin/geoPi-location"
SWITCH_DST="/usr/local/bin/geoPi-location"

LOC_DIR="/etc/geoPi/locations"
ENV_LINK="/etc/geoPi.env"

echo "[install] Installing agent and tools…"
sudo install -m 0755 "$AGENT_SRC" "$AGENT_DST"
sudo install -m 0755 "$SWITCH_SRC" "$SWITCH_DST"

echo "[install] Installing systemd unit…"
sudo install -m 0644 "$UNIT_SRC" "$UNIT_DST"

echo "[install] Installing location profiles…"
sudo mkdir -p "$LOC_DIR"
sudo install -m 0644 locations/*.env "$LOC_DIR/"

# Default to SU profile unless an env already exists
if [[ ! -L "$ENV_LINK" && ! -f "$ENV_LINK" ]]; then
  sudo ln -sf "$LOC_DIR/su.env" "$ENV_LINK"
fi

echo "[install] Enabling + starting service…"
sudo systemctl daemon-reload
sudo systemctl enable --now geoPi.service

echo "[install] Done. Use 'sudo geoPi-location list|su|ecs|sci'."
