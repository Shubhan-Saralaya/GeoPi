#!/usr/bin/env bash
# geoPi agent: run tunneld, track current --rsd, and apply simulated location
set -Eeuo pipefail

# Edit PY in /etc/geoPi.env (or here as fallback):
PY="${PY:-/path/to/venv/bin/python}"
LAT="${LAT:-33.058734}"
LON="${LON:--96.77175}"
TICK="${KEEPALIVE_SECS:-15}"                # resend cadence when healthy
RETRY_DELAY="${RETRY_DELAY:-2}"             # short retry when not ready
LOG="${LOG_PATH:-/var/log/geoPi_tunneld.log}"
STATE_FILE="/run/geoPi.rsd"

log(){ echo "[geoPi] $*"; }

# Ensure paths exist BEFORE starting tunneld so our tailer never misses lines
mkdir -p /var/log /run
: > "$LOG"
: > "$STATE_FILE"

start_tunneld() {
  log "Starting tunneld… (logging to $LOG)"
  # line-buffer output; tee to file AND journald
  stdbuf -oL -eL "$PY" -m pymobiledevice3 remote tunneld 2>&1 | tee -a "$LOG" &
  TUNNELD_PID=$!
  log "tunneld pid: $TUNNELD_PID"
}

ensure_tunneld() {
  if [[ -z "${TUNNELD_PID:-}" ]] || ! kill -0 "$TUNNELD_PID" 2>/dev/null; then
    start_tunneld
  fi
}

# background tracker: follows the tunneld log and updates STATE_FILE
track_rsd() {
  tail -n0 -F "$LOG" | while IFS= read -r line; do
    if [[ "$line" =~ Created\ tunnel\ --rsd\ ([^[:space:]]+)\ ([0-9]+) ]]; then
      echo "RSD_HOST=${BASH_REMATCH[1]} RSD_PORT=${BASH_REMATCH[2]}" > "$STATE_FILE"
      log "RSD detected: ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
    elif [[ -s "$STATE_FILE" && "$line" =~ disconnected\ from\ tunnel\ --rsd\ (.*)\ ([0-9]+) ]]; then
      disc_host="${BASH_REMATCH[1]}"; disc_port="${BASH_REMATCH[2]}"
      if grep -q "RSD_HOST=$disc_host RSD_PORT=$disc_port" "$STATE_FILE"; then
        : > "$STATE_FILE"
        log "RSD cleared (disconnect): $disc_host $disc_port"
      fi
    fi
  done
}

# Fallback: poll the log once to prime the state if tracker hasn't caught up yet
poll_latest_rsd_once() {
  if [[ ! -s "$STATE_FILE" ]]; then
    if line="$(grep -E 'Created tunnel --rsd [^ ]+ [0-9]+' "$LOG" | tail -n1)"; then
      if [[ "$line" =~ Created\ tunnel\ --rsd\ ([^[:space:]]+)\ ([0-9]+) ]]; then
        echo "RSD_HOST=${BASH_REMATCH[1]} RSD_PORT=${BASH_REMATCH[2]}" > "$STATE_FILE"
        log "RSD primed from poll: ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
      fi
    fi
  fi
}

apply_tick() {
  poll_latest_rsd_once
  if [[ -s "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    eval "$(cat "$STATE_FILE")" || true
  fi
  host="${RSD_HOST:-}"; port="${RSD_PORT:-}"
  if [[ -n "$host" && -n "$port" ]]; then
    # Try to ensure DeveloperDiskImage is mounted (harmless if already mounted)
    "$PY" -m pymobiledevice3 developer mounter auto --rsd "$host" "$port" >/dev/null 2>&1 || true
    # Fire-and-forget; ignore exit codes and output (some builds return nonzero on success)
    "$PY" -m pymobiledevice3 developer dvt simulate-location set --rsd "$host" "$port" -- "$LAT" "$LON" >/dev/null 2>&1 || true
    log "Sent location tick to $host $port (${LAT}, ${LON})"
  else
    log "No active RSD yet; waiting…"
  fi
}

trap 'kill ${TUNNELD_PID:-0} ${TRACK_PID:-0} 2>/dev/null || true' EXIT

start_tunneld
track_rsd & TRACK_PID=$!

# main: try every TICK seconds; never exit
while true; do
  ensure_tunneld
  apply_tick
  sleep "$TICK"
done
