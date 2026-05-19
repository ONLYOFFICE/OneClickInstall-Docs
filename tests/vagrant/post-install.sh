#!/bin/bash

set -e

export TERM=xterm-256color

SERVICES_SYSTEMD=(
  "ds-converter.service"
  "ds-docservice.service"
)

get_colors() {
  export LINE_SEPARATOR="-----------------------------------------"
  export COLOR_BLUE=$'\e[34m' COLOR_GREEN=$'\e[32m' COLOR_RED=$'\e[31m' COLOR_RESET=$'\e[0m' COLOR_YELLOW=$'\e[33m'
}

healthcheck_systemd_services() {
  local failed=0
  for service in "${SERVICES_SYSTEMD[@]}"; do
    if systemctl is-active --quiet "$service"; then
      echo "${COLOR_GREEN}[OK] Service ${service} is running${COLOR_RESET}"
    else
      echo "${COLOR_RED}[FAILED] Service ${service} is not running${COLOR_RESET}"
      echo "::error::Service ${service} is not running"
      failed=1
    fi
  done
  return $failed
}

services_logs() {
  for service in "${SERVICES_SYSTEMD[@]}"; do
    echo $LINE_SEPARATOR && echo "${COLOR_GREEN}Check logs for systemd service: $service${COLOR_RESET}" && echo $LINE_SEPARATOR
    journalctl -u "$service" -n 30 || true
  done

  local MAIN_LOGS_DIR="/var/log/onlyoffice"
  local DOCS_LOGS_DIR="${MAIN_LOGS_DIR}/documentserver"

  for LOGS_DIR in "${MAIN_LOGS_DIR}" "${DOCS_LOGS_DIR}"; do
    echo $LINE_SEPARATOR && echo "${COLOR_YELLOW}Check logs for $(basename "${LOGS_DIR}" | tr '[:lower:]' '[:upper:]')${COLOR_RESET}" && echo $LINE_SEPARATOR
    find "${LOGS_DIR}" -maxdepth 2 -type f -name "*.log" ! -name "*sql*" ! -name "*nginx*" 2>/dev/null | while read -r FILE; do
      echo $LINE_SEPARATOR && echo "${COLOR_GREEN}Logs from file: ${FILE}${COLOR_RESET}" && echo $LINE_SEPARATOR
      tail -30 "${FILE}" || true
    done
  done
}

healthcheck_curl() {
  local url="${url:-http://localhost}"
  local res attempts=24
  for i in $(seq 1 $attempts); do
    res=$(curl -fsSk "${url}/healthcheck" 2>/dev/null || true)
    if [[ "$res" == "true" ]]; then
      echo "${COLOR_GREEN}[OK] Healthcheck passed${COLOR_RESET}"
      return 0
    fi
    echo "Attempt ${i}/${attempts}: not ready, waiting 10s..."
    sleep 10
  done
  echo "${COLOR_RED}[FAILED] Healthcheck failed after $((attempts * 10))s (last response: ${res})${COLOR_RESET}"
  echo "::error::HTTP healthcheck failed"
  return 1
}

uninstall_docs() {
  cd "$(dirname "$0")/../.."
  # Answer "no" to dependency removal and keep Debian purge noninteractive
  DEBIAN_FRONTEND=noninteractive bash docs-install.sh --uninstall true "$@" <<< "N"
  echo "${COLOR_GREEN}[OK] Package uninstalled${COLOR_RESET}"
}

main() {
  get_colors

  case "${1:-logs}" in
    healthcheck)
      echo "${COLOR_BLUE}${LINE_SEPARATOR}${COLOR_RESET}"
      echo "${COLOR_BLUE}HEALTH CHECK${COLOR_RESET}"
      echo "${COLOR_BLUE}${LINE_SEPARATOR}${COLOR_RESET}"
      healthcheck_curl
      healthcheck_systemd_services
      ;;
    uninstall)
      echo "${COLOR_BLUE}${LINE_SEPARATOR}${COLOR_RESET}"
      echo "${COLOR_BLUE}UNINSTALL${COLOR_RESET}"
      echo "${COLOR_BLUE}${LINE_SEPARATOR}${COLOR_RESET}"
      uninstall_docs "${@:2}"
      ;;
    logs)
      echo "${COLOR_BLUE}${LINE_SEPARATOR}${COLOR_RESET}"
      echo "${COLOR_BLUE}COLLECTING SERVICE LOGS${COLOR_RESET}"
      echo "${COLOR_BLUE}${LINE_SEPARATOR}${COLOR_RESET}"
      services_logs
      ;;
    *)
      echo "Usage: $0 [healthcheck|uninstall|logs]"
      exit 1
      ;;
  esac
}

main "$@"
