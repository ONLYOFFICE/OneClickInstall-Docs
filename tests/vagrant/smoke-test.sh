#!/bin/bash
# Run browser smoke tests from the host against the Docs VM (forwarded localhost:8080).
# Optional env: EXPECTED_VERSION — assert the installed version (used by update CI).

set -e
cd "$(dirname "$0")"

if ! vagrant status | grep -q "running"; then
  echo "VM is not running, skipping smoke test"
  exit 0
fi

# make the Host header the tests use (localhost:8080) reachable from inside the VM
vagrant ssh -c "sudo sed -i '0,/listen 0.0.0.0:80/s//&;\n  &80/' /etc/onlyoffice/documentserver/nginx/ds.conf && sudo systemctl reload nginx && curl -sf http://localhost:8080/healthcheck >/dev/null" \
  || { echo "::error::failed to expose port 8080 inside the VM"; exit 1; }

PIP_BREAK_SYSTEM_PACKAGES=1 pip install -q --disable-pip-version-check -r ../smoke/requirements.txt
SERVER_URL=http://localhost:8080 CHECK_ADMINPANEL=true python3 -m pytest ../smoke/test_docs_smoke.py -v -s
