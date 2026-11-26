#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Raymond Beaudoin (synackray)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/VoltTech21/reostream

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

fetch_and_deploy_gh_release "reostream" "VoltTech21/reostream" "singlefile" "latest" "/opt/reostream" "reostream-linux-$(arch_resolve)"
[[ -x /opt/reostream/reostream ]] || mv /opt/reostream/reostream-linux-* /opt/reostream/reostream
chmod +x /opt/reostream/reostream

msg_info "Creating User and Environment File"
useradd --system --no-create-home --shell /usr/sbin/nologin reostream
install -d -m 0755 /etc/reostream
# Optional secrets referenced from config.toml as "$VAR_NAME", plus e.g.
# REOSTREAM_BATTERY_UDP_PORT=41000 for battery cameras behind a firewall
install -m 0600 /dev/null /etc/reostream/reostream.env
msg_ok "Created User and Environment File"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/reostream.service
[Unit]
Description=reostream Reolink Baichuan to RTSP/MPEG-TS proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=reostream
Group=reostream
EnvironmentFile=-/etc/reostream/reostream.env
ExecStart=/opt/reostream/reostream -data /var/lib/reostream
StateDirectory=reostream
StateDirectoryMode=0700
# Must stay SIGTERM with a generous timeout: a clean stop releases the
# cameras' sessions; SIGKILL makes them refuse connections for minutes.
KillSignal=SIGTERM
TimeoutStopSec=30
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now reostream
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc

