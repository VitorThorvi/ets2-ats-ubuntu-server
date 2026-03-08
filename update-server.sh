#!/usr/bin/env bash
set -Eeuo pipefail

APP_ID_ATS="2239530"
APP_ID_ETS="1948160"

STEAM_USER="steam"

COLOR_CYAN="\033[1;36m"
COLOR_GREEN="\033[1;32m"
COLOR_RED="\033[1;31m"
COLOR_RESET="\033[0m"

print_banner() {
  echo ""
  echo -e "${COLOR_CYAN}=============================="
  echo -e "$1"
  echo -e "==============================${COLOR_RESET}"
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
  print_banner "ATS/ETS2 Dedicated Server Updater"

  echo "Choose the game to update:"
  echo "1) American Truck Simulator (ATS)"
  echo "2) Euro Truck Simulator 2 (ETS2)"
  read -r -p "Enter 1 or 2: " escolha

  case "${escolha}" in
    1)
      GAME_NAME="American Truck Simulator"
      APP_ID="${APP_ID_ATS}"
      INSTALL_DIR="/opt/ats-dedicated"
      SERVICE_NAME="ats-dedicated"
      ;;
    2)
      GAME_NAME="Euro Truck Simulator 2"
      APP_ID="${APP_ID_ETS}"
      INSTALL_DIR="/opt/ets2-dedicated"
      SERVICE_NAME="ets2-dedicated"
      ;;
    *)
      print_error "Invalid option. Aborting."
      exit 1
      ;;
  esac
}

check_requirements() {
  print_banner "Checking requirements"

  if ! id -u "${STEAM_USER}" >/dev/null 2>&1; then
    print_error "User '${STEAM_USER}' does not exist."
    exit 1
  fi

  if ! command -v steamcmd >/dev/null 2>&1; then
    print_error "steamcmd is not installed."
    exit 1
  fi

  if [[ ! -d "${INSTALL_DIR}" ]]; then
    print_error "Install directory does not exist: ${INSTALL_DIR}"
    exit 1
  fi
}

stop_service_if_present() {
  if systemctl list-unit-files | grep -q "^${SERVICE_NAME}\.service"; then
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
      print_banner "Stopping running service"
      systemctl stop "${SERVICE_NAME}"
    fi
  fi
}

run_update() {
  print_banner "Updating ${GAME_NAME}"

  sudo -u "${STEAM_USER}" bash -lc \
    "steamcmd +force_install_dir '${INSTALL_DIR}' +login anonymous +app_update ${APP_ID} validate +quit"
}

start_service_if_present() {
  if systemctl list-unit-files | grep -q "^${SERVICE_NAME}\.service"; then
    print_banner "Starting service again"
    systemctl start "${SERVICE_NAME}" || true
  fi
}

print_summary() {
  print_banner "Update completed"
  echo -e "${COLOR_GREEN}Game:${COLOR_RESET}        ${GAME_NAME}"
  echo -e "${COLOR_GREEN}App ID:${COLOR_RESET}      ${APP_ID}"
  echo -e "${COLOR_GREEN}Install dir:${COLOR_RESET} ${INSTALL_DIR}"

  if systemctl list-unit-files | grep -q "^${SERVICE_NAME}\.service"; then
    echo -e "${COLOR_GREEN}Service:${COLOR_RESET}     ${SERVICE_NAME}"
    systemctl --no-pager --full status "${SERVICE_NAME}" || true
  else
    echo "No systemd service detected for ${SERVICE_NAME}."
  fi
}

main() {
  require_root
  choose_game
  check_requirements
  stop_service_if_present
  run_update
  start_service_if_present
  print_summary
}

main "$@"
