#!/bin/bash

set -euo pipefail

DOMAIN="docs-acme-test.invalid"
EMAIL="acme-test@example.com"
DS_CONF="/etc/onlyoffice/documentserver/nginx/ds.conf"
LETSENCRYPT_SCRIPT="/usr/bin/documentserver-letsencrypt"
export ACME_NGINX_CONF="/etc/nginx/conf.d/documentserver-letsencrypt-acme.conf"
CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
FAKE_BIN="$(mktemp -d)/bin"

reload_nginx() {
  if pgrep -x systemd >/dev/null 2>&1 && command -v systemctl >/dev/null 2>&1; then
    systemctl reload nginx
  elif command -v service >/dev/null 2>&1; then
    service nginx reload
  else
    nginx -s reload
  fi
}

[ -x "$LETSENCRYPT_SCRIPT" ] || { echo "[FAILED] $LETSENCRYPT_SCRIPT not found" >&2; exit 1; }

# Reproduce a fresh package installation with Document Server on port 8083.
rm -rf -- "$CERT_DIR" "$ACME_NGINX_CONF"
# The preceding Smoke test adds a temporary port-8080 listener to ds.conf.
sed -i '/^[[:space:]]*listen 0\.0\.0\.0:8080[[:space:]]*;/d' "$DS_CONF"
sed 's/\(listen .*:\)\([0-9]\{2,5\}\b\)\( default_server\)\?\(;\)/\1'8083'\3\4/' -i "$DS_CONF"
nginx -t
reload_nginx
[[ "$(curl -fsS --noproxy '*' http://127.0.0.1:8083/healthcheck)" == "true" ]]
if grep -Eq '^[[:space:]]*listen[[:space:]]+(0\.0\.0\.0:|\[::\]:)?80([[:space:]]|;)' "$DS_CONF"; then
  echo "[FAILED] ds.conf still listens on port 80" >&2
  exit 1
fi

mkdir -p -- "$FAKE_BIN"
cat > "${FAKE_BIN}/certbot" <<'EOF'
#!/bin/bash
set -euo pipefail

webroot=""
domain=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -w) webroot="$2"; shift 2 ;;
    -d) domain="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -n "$webroot" ] && [ -n "$domain" ]
[ -f "$ACME_NGINX_CONF" ]
challenge_dir="${webroot}/.well-known/acme-challenge"
mkdir -p -- "$challenge_dir"
printf '%s' 'oneclick-acme-ok' > "${challenge_dir}/oneclick-test"

response=""
for _ in $(seq 1 20); do
  response="$(curl -fsS --noproxy '*' --resolve "${domain}:80:127.0.0.1" \
    "http://${domain}/.well-known/acme-challenge/oneclick-test" 2>/dev/null || true)"
  [ "$response" = "oneclick-acme-ok" ] && break
  sleep 1
done
[[ "$response" == "oneclick-acme-ok" ]]

[ "${ACME_TEST_FAIL:-false}" != "true" ] || exit 42

cert_dir="/etc/letsencrypt/live/${domain}"
mkdir -p -- "$cert_dir"
openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 1 \
  -subj "/CN=${domain}" -addext "subjectAltName=DNS:${domain}" \
  -keyout "${cert_dir}/privkey.pem" -out "${cert_dir}/fullchain.pem" >/dev/null 2>&1
EOF
chmod 0755 "${FAKE_BIN}/certbot"
export PATH="${FAKE_BIN}:${PATH}"

# A failed issuance must remove the temporary listener and keep port 8083 working.
export ACME_TEST_FAIL=true
if "$LETSENCRYPT_SCRIPT" "$EMAIL" "$DOMAIN"; then
  echo "[FAILED] simulated Certbot failure was ignored" >&2
  exit 1
fi
unset ACME_TEST_FAIL
[ ! -e "$ACME_NGINX_CONF" ]
[[ "$(curl -fsS --noproxy '*' http://127.0.0.1:8083/healthcheck)" == "true" ]]

# A successful issuance must activate the existing HTTPS template.
"$LETSENCRYPT_SCRIPT" "$EMAIL" "$DOMAIN"
[ ! -e "$ACME_NGINX_CONF" ]
nginx -t
grep -Eq '^[[:space:]]*listen[[:space:]]+0\.0\.0\.0:80([[:space:]]|;)' "$DS_CONF" \
  || { echo "[FAILED] HTTPS config does not listen on port 80" >&2; exit 1; }
grep -Eq '^[[:space:]]*listen[[:space:]]+0\.0\.0\.0:443[[:space:]]+ssl' "$DS_CONF" \
  || { echo "[FAILED] HTTPS config does not listen on port 443" >&2; exit 1; }

HTTPS_HEALTH=""
HTTP_STATUS=""
for _ in $(seq 1 20); do
  HTTPS_HEALTH="$(curl -fsSk --noproxy '*' --resolve "${DOMAIN}:443:127.0.0.1" \
    "https://${DOMAIN}/healthcheck" 2>/dev/null || true)"
  HTTP_STATUS="$(curl -sS --noproxy '*' -o /dev/null -w '%{http_code}' \
    --resolve "${DOMAIN}:80:127.0.0.1" "http://${DOMAIN}/healthcheck" 2>/dev/null || true)"
  [ "$HTTPS_HEALTH" = "true" ] && [ "$HTTP_STATUS" = "301" ] && break
  sleep 1
done
[ "$HTTPS_HEALTH" = "true" ] \
  || { echo "[FAILED] HTTPS healthcheck returned: ${HTTPS_HEALTH:-empty}" >&2; exit 1; }
[ "$HTTP_STATUS" = "301" ] \
  || { echo "[FAILED] HTTP redirect returned status: ${HTTP_STATUS:-empty}" >&2; exit 1; }

echo "[OK] Let's Encrypt HTTP-01 bootstrap test passed"
