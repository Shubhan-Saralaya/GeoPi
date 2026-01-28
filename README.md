# GeoPi

One **systemd service** that:
- Starts `pymobiledevice3 remote tunneld`
- Watches for the current `--rsd <host> <port>` announced by the tunnel
- Applies a chosen GPS location to the attached iPhone on a short cadence
- Automatically recovers after unplug/replug and tunnel changes

Great for setups where your iPhone is connected to a Raspberry Pi for **data only** (no power).

---

## Requirements

- Raspberry Pi or any Linux host with `systemd`
- Python (virtualenv recommended) with [`pymobiledevice3`](https://github.com/doronz88/pymobiledevice3) installed  
  *Example path used here:* `/home/home3/apps/geopi/geopi_venv/bin/python`
- iPhone with **Developer Mode** enabled and **trusted** on the host
- `usbmuxd` running (usually installed by default on most distros)

> **Note:** Update the `PY=` value in the location profile files to match your system’s Python path.

---

## Repo Layout

```text
geoPi/
├─ README.md
├─ LICENSE
├─ systemd/geoPit.service
├─ bin/geoPi_agent.sh
├─ bin/geoPi-location
├─ locations/su.env
├─ locations/ecs.env
├─ locations/sci.env
├─ install.sh
└─ uninstall.sh
```

---

## Quick Start

```bash
git clone [https://github.com/](https://github.com/)<your-username>/geoPi.git
cd geoPi

# (Optional) Edit the PY= path inside locations/*.env to your python path
# e.g., sed -i 's#/home/home3/apps/geoPi/geoPi_venv/bin/python#/your/path/bin/python#' locations/*.env

sudo ./install.sh
```

**This script will:**
1. Install the agent to `/usr/local/bin/geoPi_agent.sh`
2. Install the profile switcher to `/usr/local/bin/geoPi-location`
3. Install `geoPi.service`
4. Copy location profiles to `/etc/geoPi/locations/`
5. Create/point `/etc/geoPi.env` → `/etc/geoPi/locations/su.env` (default)
6. Enable and start the service

**Check logs:**
```bash
sudo journalctl -u geoPi.service -f
```

---

## Switching Locations

Three profiles are included by default:
- **su** → (University of texas at Dallas, Student Union coordinates)
- **ecs** → (University of texas at Dallas, ECSS coordinates)
- **sci** → (University of texas at Dallas, Sciences coordinates)

**List and switch:**
```bash
sudo geoPi-location list
sudo geoPi-location su
sudo geoPi-location ecs
sudo geoPi-location sci
```

The command updates the symlink `/etc/geoport.env` and restarts `geoport.service`.  
The symlink persists across reboots; you do not need to re-run this after reboot unless you want to change locations.

---

## Add Your Own Location

Create a new profile file in `/etc/geoport/locations/yourplace.env`:

```ini
PY=/absolute/path/to/your/python
LAT=12.345678
LON=-98.765432
KEEPALIVE_SECS=15
RETRY_DELAY=2
```

Then point the active env to it:

```bash
sudo ln -sf /etc/geoport/locations/yourplace.env /etc/geoport.env
sudo systemctl restart geoport.service
```

*Or extend `/usr/local/bin/geoport-location` to add your new name to the case list.*

---

## Service Management

**Start / Stop / Restart**
```bash
sudo systemctl start geoPi.service
sudo systemctl stop geoPi.service
sudo systemctl restart geoPi.service
```

**Enable on boot** (install.sh already does this)
```bash
sudo systemctl enable geoport.service
```

**Status / Logs**
```bash
systemctl status geoport.service
sudo journalctl -u geoport.service -f
```

---

## Configuration

- **Profiles live at:** `/etc/geoPi/locations/*.env`
- **Active profile symlink:** `/etc/geoPi.env` (points to one of the above)
- **Tunnel log:** `/var/log/geoPi_tunneld.log`

**Each profile supports:**

| Variable | Description | Default |
| :--- | :--- | :--- |
| `PY` | Absolute path to your Python with `pymobiledevice3` | - |
| `LAT`, `LON` | Target coordinates | - |
| `KEEPALIVE_SECS` | How often to reapply when healthy | `15s` |
| `RETRY_DELAY` | Quick retry when not ready | `2s` |

---

## How It Works

1. The agent starts `pymobiledevice3 remote tunneld` and tails its log.
2. It waits for the line: `Created tunnel --rsd <host> <port>`
3. The agent stores the current `--rsd` and then reapplies the location every `KEEPALIVE_SECS`.
4. On disconnect (reading `disconnected from tunnel --rsd …`), it clears the stored `--rsd` and waits for the next "Created tunnel …" line, then resumes.

*The agent ignores CLI exit codes and sends the command on a fixed cadence, since some builds print errors or non-zero exit codes even when they succeed.*

---

## Uninstall

```bash
cd geoPi
sudo ./uninstall.sh
```

To remove profiles/logs as well:
```bash
sudo ./uninstall.sh --purge
```

---

## Troubleshooting

**No "Created tunnel …" lines in the log**
- Check `/var/log/geoPi_tunneld.log`.
- Ensure the iPhone is unlocked, trusted, and in **Developer Mode**.
- Verify `usbmuxd` is running.
- Try another cable/USB port.

**Device is not connected in logs**
- The agent retries automatically. Unplug/replug the phone if it persists.

**Service running but no location applied**
- Confirm `PY` path is correct in your active env (`/etc/geoport.env`).
- Run the command manually to validate the path:
  ```bash
  sudo $PY -m pymobiledevice3 --help
  ```
- Check that your profile has valid numeric `LAT`/`LON`.

**Switching locations after reboot**
- Not required. The `/etc/geoport.env` symlink persists.

---

## Security Notes

- The service runs as **root** to access USB and system resources.
- Profiles are world-readable by default; if you prefer, restrict read permissions on `/etc/geoport.env` and `/etc/geoport/locations/*.env`.

---

## Contributing

Issues and PRs are welcome.
**Ideas:** add CI (shellcheck), improve profile manager UX, add status subcommand.

## License

MIT License — see [LICENSE](LICENSE).
