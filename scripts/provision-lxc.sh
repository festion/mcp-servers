#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/festion/homelab-gitops-auditor/main/scripts/build.func)

APP="GitOps Dashboard"
var_tags="dashboard;gitops"
var_cpu="2"
var_ram="512"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="1"
GIT_REPO="https://github.com/festion/homelab-gitops-auditor.git"
SERVICE_PORT=8080
CT_HOSTNAME="gitopsdashboard"

header_info "$APP"
variables
color
catch_errors

CTID=$(pct list | awk -v host="$CT_HOSTNAME" '$3 == host {print $1}')

if [[ -n "$CTID" ]]; then
  msg_ok "Container for ${APP} already exists (CTID: ${CTID}). Updating existing container."

  msg_info "Stopping ${APP}"
  pct exec $CTID -- systemctl stop gitops-dashboard
  sleep 2
  msg_ok "Stopped ${APP}"
else
  start
  build_container
  description
fi

msg_info "Installing dependencies"
pct exec $CTID -- bash -c "apt update >/dev/null 2>&1 && apt install -y git curl npm nodejs python3 >/dev/null 2>&1"
msg_ok "Installed dependencies"

msg_info "Setting up ${APP}"
pct exec $CTID -- bash -c "rm -rf /opt/gitops && git clone --depth=1 $GIT_REPO /opt/gitops && cd /opt/gitops/dashboard && npm install && npm run build && mkdir -p /var/www/gitops-dashboard && cp -r dist/* /var/www/gitops-dashboard/"

SERVICE_FILE="[Unit]\nDescription=GitOps Dashboard\nAfter=network.target\n\n[Service]\nWorkingDirectory=/var/www/gitops-dashboard\nExecStart=/usr/bin/python3 -m http.server ${SERVICE_PORT}\nRestart=always\n\n[Install]\nWantedBy=multi-user.target"

pct exec $CTID -- bash -c "echo -e '$SERVICE_FILE' > /etc/systemd/system/gitops-dashboard.service && systemctl daemon-reload && systemctl enable --now gitops-dashboard.service"
msg_ok "Setup Completed"

IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:${SERVICE_PORT}${CL}"