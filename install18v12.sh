#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/odoo/odoo

APP="Odoo"
var_tags="${var_tags:-erp}"
var_disk="${var_disk:-6}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  

  if [[ ! -f /etc/odoo/odoo.conf ]]; then
    msg_error "No Odoo Installation Found!"
    exit
  fi
  if ! [[ $(dpkg -s python3-lxml-html-clean 2>/dev/null) ]]; then
    $STD apt install python3-lxml
    curl -fsSL "http://archive.ubuntu.com/ubuntu/pool/universe/l/lxml-html-clean/python3-lxml-html-clean_0.1.1-1_all.deb" -o /opt/python3-lxml-html-clean.deb
    $STD dpkg -i /opt/python3-lxml-html-clean.deb
    rm -f /opt/python3-lxml-html-clean.deb
  fi

  RELEASE="18.0"
  LATEST_VERSION="18.0.20251220"

  if [[ "18.0.20251220" != "$(cat /opt/Odoo_version.txt)" ]] || [[ ! -f /opt/Odoo_version.txt ]]; then
    msg_info "Stopping Odoo service"
    systemctl stop odoo
    msg_ok "Stopped Service"

    msg_info "Updating Odoo to 18.0.20251220"
    curl -fsSL https://nightly.odoo.com/18.0/nightly/deb/odoo_18.0.20251220_all.deb -o /opt/odoo.deb
    $STD apt install -y /opt/odoo.deb
    rm -f /opt/odoo.deb
    echo "$LATEST_VERSION" >/opt/Odoo_version.txt
    msg_ok "Updated Odoo to 18.0.20251220"

    msg_info "Starting Service"
    systemctl start odoo
    msg_ok "Started Service"
    msg_ok "Updated successfully!"
  else
    msg_ok "No update required. Odoo is already at 18.0.20251220"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}Odoo setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Accede usando la siguiente URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8069${CL}"
