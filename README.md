# reostream LXC for Proxmox VE

Runs [reostream](https://github.com/VoltTech21/reostream) natively in a Debian LXC container, with no Docker. reostream is a Reolink camera proxy. It pulls video over Reolink's Baichuan protocol and serves it to Frigate, go2rtc, Blue Iris, VLC or mpv as RTSP and HTTP MPEG-TS.

This is a [Community Scripts](https://community-scripts.github.io/ProxmoxVE/) (ProxmoxVE) script. It installs the upstream static binary, creates a systemd service and supports in-place updates. This script does not meet the minimum requirements, so I am hosting it separately for now with a best effort maintenance warranty.

## Install

Run this in the **Proxmox VE host shell**:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/synackray/lxc-reostream/main/ct/reostream.sh)"
```

Choose **Default** or **Advanced** settings in the dialog.

## Defaults

| Setting      | Value                      |
|--------------|----------------------------|
| OS           | Debian 13                  |
| CPU          | 1 core                     |
| RAM          | 512 MB                     |
| Disk         | 4 GB                       |
| Container    | Unprivileged               |
| Architecture | amd64 and arm64            |

All values can be changed in Advanced mode or with `var_*` environment variables.

## First run

1. Get the one-time claim token. It is held in memory only, and a restart before claiming prints a new one.

   ```bash
   journalctl -u reostream | grep -i token
   ```

2. Open `http://<container-ip>:8562/claim` and paste the token.
3. Keep the generated password. The control page asks for it from now on.
4. Add cameras from the page. It searches the network and lists what it finds. A wired camera must have port 9000 reachable, which is the default.

## Ports

| Port        | Protocol | Purpose                                   |
|-------------|----------|-------------------------------------------|
| 8562        | TCP      | Web control page (always password-protected) |
| 8561        | TCP      | RTSP: `rtsp://<ip>:8561/<camera>`         |
| 8560        | TCP      | HTTP MPEG-TS: `http://<ip>:8560/<camera>.ts`, `/api/status`, `/metrics` |
| 2121–2131   | TCP      | Optional FTP clip receiver                |

The streaming ports (8560 and 8561) are open to the network by default. To require a login, set `username` and `password` under `[rtsp]` in the config.

Each camera also has `_sub` and `_extern` variants, for example `rtsp://<ip>:8561/<camera>_sub`.

## Update

Run this inside the container console:

```bash
update
```

Alternatively, re-run the install command from the Proxmox host and choose the update option. The script checks the latest GitHub release and only updates when a newer one exists. It stops the service, replaces the binary and restarts it. Your config and data are kept.

## Paths

| Path                                  | Purpose                                      |
|---------------------------------------|----------------------------------------------|
| `/opt/reostream/reostream`            | Binary (replaced on update)                  |
| `/var/lib/reostream/config.toml`      | Config, written when you claim               |
| `/etc/reostream/reostream.env`        | Optional environment variables (mode 0600)   |
| `/etc/systemd/system/reostream.service` | systemd unit                               |

## Configuration

Edit the config from the web page, or by hand:

```bash
nano /var/lib/reostream/config.toml
systemctl restart reostream
```

- Add to the existing file and do not replace it. A config without a `[control]` section is treated as unclaimed.
- Unknown keys stop startup with an error, so a typo fails at boot instead of serving 404s.
- Values starting with `$` are read from the environment. Put secrets in `/etc/reostream/reostream.env`:

  ```bash
  REOSTREAM_DRIVEWAY_PASSWORD=changeme
  ```

  ```toml
  [[camera]]
  name = "driveway"
  address = "192.0.2.50"
  username = "admin"
  password = "$REOSTREAM_DRIVEWAY_PASSWORD"
  ```

  A variable that is referenced but not set stops startup with an error.

### FTP clip receiver

The service runs with `ProtectSystem=strict`, so clips must be saved under `/var/lib/reostream`. Upstream's default `/data/clips` is not writable here.

```toml
[ftp]
listen = ":2121"            # data ports 2122-2131
dir = "/var/lib/reostream/clips"
keep_days = 14
```

If you enable "Auto-save motion clips" from the web page, check that `dir` has this value afterwards.

### Battery cameras

Battery cameras are discovered by their own UDP search. If the container has a firewall, pin the reply port and allow it:

```bash
echo 'REOSTREAM_BATTERY_UDP_PORT=41000' >> /etc/reostream/reostream.env
systemctl restart reostream
```

Then allow inbound UDP 41000 to the container.

## Service management

```bash
systemctl status reostream
systemctl restart reostream
journalctl -u reostream -f
```

> **Do not change `KillSignal=SIGTERM` or `TimeoutStopSec=30` in the unit.** reostream closes camera sessions cleanly on shutdown. If it is killed first, cameras can refuse new connections for several minutes.

## Networking

The container uses a bridged interface with its own IP, so no host networking is needed. Camera discovery and FTP uploads from cameras work as long as the container is on the same LAN or VLAN as the cameras. Give the container a static IP or a DHCP reservation, because your NVR and cameras point at it.

## Using with Frigate

Point Frigate (or go2rtc) at the RTSP streams:

```yaml
cameras:
  driveway:
    ffmpeg:
      inputs:
        - path: rtsp://<container-ip>:8561/driveway
          roles: [record]
        - path: rtsp://<container-ip>:8561/driveway_sub
          roles: [detect]
```

The web page's **Settings → Connect to NVR** tab generates URLs for Frigate, go2rtc, Blue Iris and Home Assistant.

## Uninstall

Destroy the container from the Proxmox VE UI, or run `pct destroy <CTID>` on the host.

## Links

- Upstream project and docs: <https://github.com/VoltTech21/reostream>
- Supported and tested cameras: see the upstream README
- Community Scripts contribution guide: <https://community-scripts.github.io/ProxmoxVE/>

## License

- These scripts: MIT, as with all Community Scripts.
- reostream itself: AGPL v3. A commercial license is available from upstream.

