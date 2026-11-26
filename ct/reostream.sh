#!/usr/bin/env bash
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Raymond Beaudoin (synackray)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/VoltTech21/reostream

APP="reostream"
var_tags="${var_tags:-camera;nvr;proxy}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-yes}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/reostream ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "reostream" "VoltTech21/reostream"; then
    msg_info "Stopping Service"
    systemctl stop reostream
    msg_ok "Stopped Service"

    fetch_and_deploy_gh_release "reostream" "VoltTech21/reostream" "singlefile" "latest" "/opt/reostream" "reostream-linux-$(arch_resolve)"
    [[ -x /opt/reostream/reostream ]] || mv /opt/reostream/reostream-linux-* /opt/reostream/reostream
    chmod +x /opt/reostream/reostream

    msg_info "Starting Service"
    systemctl start reostream
    msg_ok "Started Service"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Get the one-time claim token inside the container:${CL}"
echo -e "${TAB}${BGN}journalctl -u reostream | grep -i token${CL}"
echo -e "${INFO}${YW}Then open the claim page:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8562/claim${CL}"
echo -e "${INFO}${YW}Streams: rtsp://${IP}:8561/<camera>  http://${IP}:8560/<camera>.ts${CL}"

