#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/odoo/odoo

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/install.func)

APP="Odoo"
var_tags="${var_tags:-erp}"
var_disk="${var_disk:-15}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-4096}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors
verb_ip6

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /etc/odoo/odoo.conf ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  if ! [[ $(dpkg -s python3-lxml-html-clean 2>/dev/null) ]]; then
    $STD apt install python3-lxml
    curl -fsSL "http://archive.ubuntu.com/ubuntu/pool/universe/l/lxml-html-clean/python3-lxml-html-clean_0.1.1-1_all.deb" -o /opt/python3-lxml-html-clean.deb
    $STD dpkg -i /opt/python3-lxml-html-clean.deb
    rm -f /opt/python3-lxml-html-clean.deb
  fi

  RELEASE="18.0"

  msg_info "Stopping ${APP} Service"
  systemctl stop odoo
  msg_ok "Stopped Service"

  msg_info "Updating ${APP} to ${RELEASE}"
  curl -fsSL "https://nightly.odoo.com/${RELEASE}/nightly/deb/odoo_${RELEASE}.latest_all.deb" -o /opt/odoo.deb
  $STD apt install -y --no-upgrade /opt/odoo.deb
  rm -f /opt/odoo.deb
  echo "${RELEASE}" >/opt/${APP}_version.txt
  msg_ok "Updated ${APP} to ${RELEASE}"

  msg_info "Starting ${APP} Service"
  systemctl start odoo
  msg_ok "Started Service"
  msg_ok "Update Completed Successfully"
  exit
}

start
build_container
description

msg_info "Installing Dependencies"
$STD apt install -y python3-lxml wkhtmltopdf
curl -fsSL "http://archive.ubuntu.com/ubuntu/pool/universe/l/lxml-html-clean/python3-lxml-html-clean_0.1.1-1_all.deb" -o /opt/python3-lxml-html-clean.deb
$STD dpkg -i /opt/python3-lxml-html-clean.deb
msg_ok "Installed Dependencies"

RELEASE="18.0"
PG_VERSION="18"
setup_postgresql

msg_info "Setup Odoo ${RELEASE}"
curl -fsSL "https://nightly.odoo.com/${RELEASE}/nightly/deb/odoo_${RELEASE}.latest_all.deb" -o /opt/odoo.deb
$STD apt install -y --no-upgrade /opt/odoo.deb
msg_ok "Setup Odoo ${RELEASE}"

msg_info "Setup PostgreSQL Database"
DB_NAME="odoo"
DB_USER="odoo_usr"
DB_PASS="$(openssl rand -base64 18 | cut -c1-13)"
$STD su - postgres -c "psql -c \"CREATE DATABASE $DB_NAME;\""
$STD sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
$STD sudo -u postgres psql -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"
$STD sudo -u postgres psql -c "ALTER USER $DB_USER WITH SUPERUSER;"
{
  echo "Odoo-Credentials"
  echo -e "Odoo Database User: $DB_USER"
  echo -e "Odoo Database Password: $DB_PASS"
  echo -e "Odoo Database Name: $DB_NAME"
} >>~/odoo.creds
msg_ok "Setup PostgreSQL"

msg_info "Configuring Odoo"
sed -i \
  -e "s|^;*db_host *=.*|db_host = localhost|" \
  -e "s|^;*db_port *=.*|db_port = 5432|" \
  -e "s|^;*db_user *=.*|db_user = $DB_USER|" \
  -e "s|^;*db_password *=.*|db_password = $DB_PASS|" \
  /etc/odoo/odoo.conf
$STD su - odoo -c "odoo -c /etc/odoo/odoo.conf -d odoo -i base --stop-after-init"
rm -f /opt/odoo.deb
rm -f /opt/python3-lxml-html-clean.deb
echo "${RELEASE}" >/opt/${APP}_version.txt
msg_ok "Configured Odoo"

msg_info "Restarting Odoo"
systemctl restart odoo
msg_ok "Restarted Odoo"

motd_ssh
customize
cleanup_lxc

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8069${CL}"
