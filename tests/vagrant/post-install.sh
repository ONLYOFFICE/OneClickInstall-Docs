#!/bin/bash

set -e

export TERM=xterm-256color

SERVICES_SYSTEMD=(
  "ds-converter.service"
  "ds-docservice.service"
  "nginx.service"
)

package_info() {
  local package files
  local -a packages=()
  for package in onlyoffice-documentserver onlyoffice-documentserver-ee onlyoffice-documentserver-de; do
    if command -v dpkg-query >/dev/null 2>&1; then
      [ "$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null)" = 'install ok installed' ] || continue
      files=$(dpkg-query -L "$package") || return 1
    else
      rpm -q "$package" >/dev/null 2>&1 || continue
      files=$(rpm -ql "$package") || return 1
    fi
    packages+=("$package")
    case "$package" in
      *-ee) DOCS_EDITION=enterprise; DOCS_ADMINPANEL=true ;;
      *-de) DOCS_EDITION=developer; DOCS_ADMINPANEL=true ;;
      *)
        DOCS_EDITION=community
        DOCS_ADMINPANEL=false
        # Older Community packages shipped the panel. Use the package manifest,
        # not the presence of an installed file: a missing unit must still fail.
        if grep -q '/ds-adminpanel\.service$' <<< "$files"; then DOCS_ADMINPANEL=true; fi
        ;;
    esac
  done
  if [ "${#packages[@]}" != 1 ]; then
    echo "::error::Expected exactly one installed ONLYOFFICE Docs package" >&2
    return 1
  fi
}

get_colors() {
  export LINE_SEPARATOR="-----------------------------------------"
  export COLOR_BLUE=$'\e[34m' COLOR_GREEN=$'\e[32m' COLOR_RED=$'\e[31m' COLOR_RESET=$'\e[0m' COLOR_YELLOW=$'\e[33m'
}

healthcheck_systemd_services() {
  local failed=0
  local -a services=("${SERVICES_SYSTEMD[@]}")
  [ "${DOCS_ADMINPANEL:-false}" != true ] || services+=(ds-adminpanel.service)
  for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
      echo "${COLOR_GREEN}[OK] Service ${service} is running${COLOR_RESET}"
    else
      echo "${COLOR_RED}[FAILED] Service ${service} is not running${COLOR_RESET}"
      echo "::error::Service ${service} is not running"
      failed=1
    fi
    if [[ "$service" == ds-* ]] && ! systemctl is-enabled --quiet "$service"; then
      echo "::error::Service $service is not enabled for boot"
      failed=1
    fi
  done
  return $failed
}

healthcheck_adminpanel() {
  [ "$DOCS_ADMINPANEL" = true ] || return 0
  if [ "$(curl -sS --max-time 30 -o /dev/null -w '%{http_code}' "${url:-http://localhost}/admin/")" != 200 ]; then
    echo "::error::AdminPanel is required by the package but does not respond with HTTP 200"
    return 1
  fi
  echo "${COLOR_GREEN}[OK] AdminPanel responds${COLOR_RESET}"
}

services_logs() {
  for service in "${SERVICES_SYSTEMD[@]}" ds-adminpanel.service; do
    echo $LINE_SEPARATOR && echo "${COLOR_GREEN}Check logs for systemd service: $service${COLOR_RESET}" && echo $LINE_SEPARATOR
    journalctl -u "$service" -n 30 || true
  done

  local MAIN_LOGS_DIR="/var/log/onlyoffice"
  local DOCS_LOGS_DIR="${MAIN_LOGS_DIR}/documentserver"

  for LOGS_DIR in "${MAIN_LOGS_DIR}" "${DOCS_LOGS_DIR}" "/var/log/nginx"; do
    echo $LINE_SEPARATOR && echo "${COLOR_YELLOW}Check logs for $(basename "${LOGS_DIR}" | tr '[:lower:]' '[:upper:]')${COLOR_RESET}" && echo $LINE_SEPARATOR
    find "${LOGS_DIR}" -maxdepth 2 -type f -name "*.log" ! -name "*sql*" 2>/dev/null | while read -r FILE; do
      echo $LINE_SEPARATOR && echo "${COLOR_GREEN}Logs from file: ${FILE}${COLOR_RESET}" && echo $LINE_SEPARATOR
      tail -30 "${FILE}" || true
    done
  done
}

healthcheck_nginx() {
  local failed=0

  if nginx -t &>/dev/null; then
    echo "${COLOR_GREEN}[OK] nginx config test passed${COLOR_RESET}"
  else
    echo "${COLOR_RED}[FAILED] nginx config test failed${COLOR_RESET}"
    nginx -t || true
    echo "::error::nginx -t failed"
    failed=1
  fi

  if nginx -V 2>&1 | grep -q -- '--with-http_secure_link_module'; then
    echo "${COLOR_GREEN}[OK] nginx has http_secure_link_module${COLOR_RESET}"
  else
    echo "${COLOR_RED}[FAILED] nginx is missing http_secure_link_module (nginx-core instead of nginx-extras/nginx.org build?)${COLOR_RESET}"
    echo "::error::nginx is missing http_secure_link_module"
    failed=1
  fi

  if nginx -V 2>&1 | grep -q -- '--with-http_gzip_static_module'; then
    echo "${COLOR_GREEN}[OK] nginx has http_gzip_static_module${COLOR_RESET}"
  else
    echo "${COLOR_RED}[FAILED] nginx is missing http_gzip_static_module (nginx-core instead of nginx-extras/nginx.org build?)${COLOR_RESET}"
    echo "::error::nginx is missing http_gzip_static_module"
    failed=1
  fi

  return $failed
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

healthcheck_example() {
  if systemctl start ds-example.service; then
    sleep 2
  fi

  if systemctl is-active --quiet ds-example.service; then
    # Wait for the example endpoint and warm its /meta/config cache
    for _ in $(seq 1 60); do
      if curl -sfL -o /dev/null "http://localhost/example/editor?fileExt=docx"; then
        echo "${COLOR_GREEN}[OK] ds-example.service is ready${COLOR_RESET}"
        return 0
      fi
      sleep 1
    done
  fi

  echo "${COLOR_RED}[FAILED] ds-example.service failed to become ready${COLOR_RESET}"
  journalctl -u ds-example.service -n 50 || true
  tail -50 /var/log/onlyoffice/documentserver-example/out.log 2>/dev/null || true
  echo "::error::ds-example.service failed to become ready"
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
      local status=0
      package_info || return 1
      if [ -n "${2:-}" ] && [ "$2" != "$DOCS_EDITION" ]; then
        echo "::error::Installed edition $DOCS_EDITION differs from requested $2"
        return 1
      fi
      healthcheck_nginx || status=1
      if healthcheck_curl; then
        healthcheck_adminpanel || status=1
      else
        status=1
      fi
      healthcheck_systemd_services || status=1
      healthcheck_example || status=1
      return "$status"
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
      echo "Usage: $0 healthcheck [community|enterprise|developer] | uninstall | logs"
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
