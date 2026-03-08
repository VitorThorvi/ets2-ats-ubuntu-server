#!/usr/bin/env bash
set -Eeuo pipefail

# ======================================
# ATS / ETS2 Dedicated Server Installer
# Ubuntu Server 22.04+
# ======================================

APP_ID_ATS="2239530"
APP_ID_ETS="1948160"

STEAM_USER="steam"
STEAM_HOME="/home/${STEAM_USER}"

COLOR_CYAN="\033[1;36m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[1;31m"
COLOR_RESET="\033[0m"

print_banner() {
  echo ""
  echo -e "${COLOR_CYAN}=============================="
  echo -e "$1"
  echo -e "==============================${COLOR_RESET}"
}

print_warn() {
  echo -e "${COLOR_YELLOW}WARNING:${COLOR_RESET} $1"
}

print_error() {
  echo -e "${COLOR_RED}ERROR:${COLOR_RESET} $1"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    print_error "Please run this script as root: sudo $0"
    exit 1
  fi
}

choose_game() {
  print_banner "ATS/ETS2 Dedicated Server Installer"

  echo "Choose the game to install:"
  echo "1) American Truck Simulator (ATS)"
  echo "2) Euro Truck Simulator 2 (ETS2)"
  read -r -p "Enter 1 or 2: " escolha

  case "${escolha}" in
    1)
      GAME_SLUG="ats"
      GAME_NAME="American Truck Simulator"
      APP_ID="${APP_ID_ATS}"
      INSTALL_DIR="/opt/ats-dedicated"
      SERVICE_NAME="ats-dedicated"
      BINARY_NAME="amtrucks_server"
      ;;
    2)
      GAME_SLUG="ets2"
      GAME_NAME="Euro Truck Simulator 2"
      APP_ID="${APP_ID_ETS}"
      INSTALL_DIR="/opt/ets2-dedicated"
      SERVICE_NAME="ets2-dedicated"
      BINARY_NAME="eurotrucks2_server"
      ;;
    *)
      print_error "Invalid option. Aborting."
      exit 1
      ;;
  esac

  print_banner "Selected game: ${GAME_NAME}"
  echo "App ID:           ${APP_ID}"
  echo "Install path:     ${INSTALL_DIR}"
  echo "Service user:     ${STEAM_USER}"
  echo "Service name:     ${SERVICE_NAME}"
}

prepare_system() {
  print_banner "Preparing Ubuntu packages"

  apt-get update

  if ! dpkg --print-foreign-architectures | grep -qx "i386"; then
    dpkg --add-architecture i386
  fi

  # Enable multiverse if not already present
  if ! grep -Rhs "^[^#].*multiverse" /etc/apt/sources.list /etc/apt/sources.list.d/* >/dev/null 2>&1; then
    apt-get install -y software-properties-common
    add-apt-repository -y multiverse
  fi

  apt-get update

  apt-get install -y \
    ca-certificates \
    curl \
    lib32gcc-s1 \
    steamcmd
}

ensure_steam_user() {
  print_banner "Ensuring dedicated service user exists"

  if ! id -u "${STEAM_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${STEAM_USER}"
    echo "Created user: ${STEAM_USER}"
  else
    echo "User already exists: ${STEAM_USER}"
  fi
}

install_server() {
  print_banner "Installing dedicated server files"

  mkdir -p "${INSTALL_DIR}"
  chown -R "${STEAM_USER}:${STEAM_USER}" "${INSTALL_DIR}"

  local steamcmd_bin=""
  if command -v steamcmd >/dev/null 2>&1; then
    steamcmd_bin="$(command -v steamcmd)"
  elif [[ -x /usr/games/steamcmd ]]; then
    steamcmd_bin="/usr/games/steamcmd"
  elif [[ -x /usr/lib/games/steamcmd ]]; then
    steamcmd_bin="/usr/lib/games/steamcmd"
  elif [[ -x /usr/lib/games/steamcmd/steamcmd.sh ]]; then
    steamcmd_bin="/usr/lib/games/steamcmd/steamcmd.sh"
  else
    print_error "steamcmd binary not found after installation."
    exit 1
  fi

  sudo -u "${STEAM_USER}" bash -lc \
    "\"${steamcmd_bin}\" +force_install_dir '${INSTALL_DIR}' +login anonymous +app_update ${APP_ID} validate +quit"
}

setup_steamclient_link() {
  print_banner "Configuring steamclient.so symlink"

  sudo -u "${STEAM_USER}" bash -lc '
    set -euo pipefail
    mkdir -p "$HOME/.steam/sdk64"

    if [[ -f "$HOME/steamcmd/linux64/steamclient.so" ]]; then
      ln -sfn "$HOME/steamcmd/linux64/steamclient.so" "$HOME/.steam/sdk64/steamclient.so"
      echo "Linked from $HOME/steamcmd/linux64/steamclient.so"
    elif [[ -f "/usr/lib/games/steamcmd/linux64/steamclient.so" ]]; then
      ln -sfn "/usr/lib/games/steamcmd/linux64/steamclient.so" "$HOME/.steam/sdk64/steamclient.so"
      echo "Linked from /usr/lib/games/steamcmd/linux64/steamclient.so"
    else
      echo "steamclient.so not found in expected locations."
      exit 1
    fi
  '
}

create_launcher() {
  print_banner "Creating launcher script"

  cat > "/usr/local/bin/${SERVICE_NAME}-start" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_DIR="${INSTALL_DIR}"
cd "\${INSTALL_DIR}"

# Prefer SCS helper launcher when present
if [[ -x "./server_launch.sh" ]]; then
  exec sudo -u ${STEAM_USER} ./server_launch.sh "\$@"
fi

# Fallback: search common binary locations
if [[ -x "./${BINARY_NAME}" ]]; then
  exec sudo -u ${STEAM_USER} "./${BINARY_NAME}" "\$@"
fi

if [[ -x "./bin/linux_x64/${BINARY_NAME}" ]]; then
  exec sudo -u ${STEAM_USER} "./bin/linux_x64/${BINARY_NAME}" "\$@"
fi

echo "Could not find a launchable server binary in:"
echo "  \${INSTALL_DIR}"
exit 1
EOF

  chmod +x "/usr/local/bin/${SERVICE_NAME}-start"
}

create_homedir_hint() {
  print_banner "Preparing server home hint"

  cat > "${INSTALL_DIR}/README-FIRST-LAUNCH.txt" <<EOF
${GAME_NAME} dedicated server notes

1. Start the server once:
   sudo -u ${STEAM_USER} /usr/local/bin/${SERVICE_NAME}-start

2. First launch creates the server home directory and default server_config.sii.

3. You must provide:
   - server_packages.sii
   - server_packages.dat

   These must be exported from a normal game installation using:
   export_server_packages

4. Copy those files into the server home directory for the '${STEAM_USER}' user.

5. Then start the server again.
EOF

  chown "${STEAM_USER}:${STEAM_USER}" "${INSTALL_DIR}/README-FIRST-LAUNCH.txt"
}

maybe_create_systemd_service() {
  print_banner "Optional systemd service"

  read -r -p "Create a systemd service for ${SERVICE_NAME}? [y/N]: " create_service
  if [[ ! "${create_service}" =~ ^[Yy]$ ]]; then
    echo "Skipping systemd service creation."
    return
  fi

  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=${GAME_NAME} Dedicated Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${STEAM_USER}
Group=${STEAM_USER}
WorkingDirectory=${INSTALL_DIR}
Environment=HOME=${STEAM_HOME}
ExecStart=${INSTALL_DIR}/server_launch.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  # If server_launch.sh doesn't exist but binary does, adjust service
  if [[ ! -x "${INSTALL_DIR}/server_launch.sh" ]]; then
    if [[ -x "${INSTALL_DIR}/${BINARY_NAME}" ]]; then
      sed -i "s|^ExecStart=.*|ExecStart=${INSTALL_DIR}/${BINARY_NAME}|" "/etc/systemd/system/${SERVICE_NAME}.service"
    elif [[ -x "${INSTALL_DIR}/bin/linux_x64/${BINARY_NAME}" ]]; then
      sed -i "s|^ExecStart=.*|ExecStart=${INSTALL_DIR}/bin/linux_x64/${BINARY_NAME}|" "/etc/systemd/system/${SERVICE_NAME}.service"
    fi
  fi

  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME}.service"

  echo ""
  echo "Service created."
  echo "Start with:  systemctl start ${SERVICE_NAME}"
  echo "Status with: systemctl status ${SERVICE_NAME}"
}

print_summary() {
  print_banner "Installation completed"

  echo -e "${COLOR_GREEN}Game:${COLOR_RESET}           ${GAME_NAME}"
  echo -e "${COLOR_GREEN}Install dir:${COLOR_RESET}    ${INSTALL_DIR}"
  echo -e "${COLOR_GREEN}Launcher:${COLOR_RESET}       /usr/local/bin/${SERVICE_NAME}-start"
  echo -e "${COLOR_GREEN}User:${COLOR_RESET}           ${STEAM_USER}"

  echo ""
  echo "Next steps:"
  echo "1) Start once to generate default config:"
  echo "   sudo -u ${STEAM_USER} /usr/local/bin/${SERVICE_NAME}-start"
  echo ""
  echo "2) Export from a normal game installation:"
  echo "   export_server_packages"
  echo ""
  echo "3) Copy these files to the server home directory:"
  echo "   server_packages.sii"
  echo "   server_packages.dat"
  echo ""
  echo "4) Start the server again."
  echo ""
  print_warn "If the server fails on first run because packages are missing, that is expected until you copy server_packages.sii and server_packages.dat."
}

main() {
  require_root
  choose_game
  prepare_system
  ensure_steam_user
  install_server
  setup_steamclient_link
  create_launcher
  create_homedir_hint
  maybe_create_systemd_service
  print_summary
}

main "$@"
