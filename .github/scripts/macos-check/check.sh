#!/bin/bash
# Checks the macOS-specific paths of the Docker installer on a real macOS runner without a Docker VM: docker is a fake CLI.
# It covers the Homebrew bootstrap, bash 3.2 and BSD tools, OS and port detection, the Docker Desktop start, the data directory and the volumes of the paid editions.
# It does not start any container, so it says nothing about the product itself.

set -u

REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
FAKE_BIN="${REPO_DIR}/.github/scripts/macos-check/fake-bin"
WORK_DIR="$(mktemp -d)"
FAILURES=0
FAILURES_BEFORE=0
SCENARIO_NUMBER=0

chmod +x "${FAKE_BIN}/docker" "${FAKE_BIN}/open"

# The wrapper and the installer side by side, as a user downloads them
INSTALL_DIR="${WORK_DIR}/docs"
mkdir -p "${INSTALL_DIR}"
cp "${REPO_DIR}/docs-install.sh" "${REPO_DIR}/install.sh" "${INSTALL_DIR}/"
echo "dummy license" > "${WORK_DIR}/license.lic"

# Every scenario gets its own HOME and fake Docker state, so nothing leaks between them
new_scenario () {
    SCENARIO_NUMBER=$((SCENARIO_NUMBER + 1))
    SCENARIO_NAME="$1"
    SCENARIO_HOME="${WORK_DIR}/home${SCENARIO_NUMBER}"
    FAKE_DOCKER_STATE="${WORK_DIR}/state${SCENARIO_NUMBER}"
    OUT_FILE="${WORK_DIR}/out${SCENARIO_NUMBER}.txt"
    mkdir -p "${SCENARIO_HOME}" "${FAKE_DOCKER_STATE}"
    : > "${FAKE_DOCKER_STATE}/docker.log"
    echo "::group::${SCENARIO_NUMBER}. ${SCENARIO_NAME}"
}

# Runs the installer wrapper the way a user does, without sudo; Docker Desktop is stopped unless the state says otherwise
run_wrapper () {
    ( cd "${INSTALL_DIR}" && HOME="${SCENARIO_HOME}" FAKE_DOCKER_STATE="${FAKE_DOCKER_STATE}" PATH="${FAKE_BIN}:${PATH}" \
        bash docs-install.sh "$@" < /dev/null ) > "${OUT_FILE}" 2>&1
    RC=$?
}

fail () {
    echo "FAIL: $1"
    FAILURES=$((FAILURES + 1))
}

expect_rc () {
    [ "${RC}" -eq "$1" ] || fail "exit code ${RC}, expected $1"
}

expect_output () {
    grep -qF -- "$1" "${OUT_FILE}" || fail "the output has no '$1'"
}

expect_log () {
    grep -qF -- "$1" "${FAKE_DOCKER_STATE}/docker.log" || fail "no '$1' in the docker calls"
}

expect_no_log () {
    ! grep -qF -- "$1" "${FAKE_DOCKER_STATE}/docker.log" || fail "unexpected '$1' in the docker calls"
}

end_scenario () {
    if [ "${FAILURES}" -ne "${FAILURES_BEFORE}" ]; then
        echo "--- installer output (last 40 lines):"
        tail -n 40 "${OUT_FILE}"
        echo "--- docker calls:"
        cat "${FAKE_DOCKER_STATE}/docker.log"
    fi
    FAILURES_BEFORE=${FAILURES}
    echo "::endgroup::"
}

# The first run also installs the Homebrew formulae, which takes a while
new_scenario "Community install with Docker Desktop stopped"
run_wrapper -ls true -it community -dv 9.1.0 -skiphc true
expect_rc 0
expect_output "Starting Docker Desktop"
expect_output "Thank you for installing"
expect_log "open /Applications/Docker.app"
expect_log "network create"
expect_log "pull onlyoffice/documentserver:9.1.0"
expect_log "-p 80:80"
expect_log "-v ${SCENARIO_HOME}/onlyoffice/DocumentServer/data:/var/www/onlyoffice/Data"
for DIRECTORY in data logs fonts forgotten; do
    [ -d "${SCENARIO_HOME}/onlyoffice/DocumentServer/${DIRECTORY}" ] || fail "no ~/onlyoffice/DocumentServer/${DIRECTORY}"
done
# 32 random characters, made by get_random_str with the GNU tr
grep -qE 'JWT_SECRET=[A-Za-z0-9]{32}( |$)' "${FAKE_DOCKER_STATE}/docker.log" || fail "the JWT secret is missing or has a wrong length"
end_scenario

new_scenario "Enterprise install keeps PostgreSQL, RabbitMQ and Redis in Docker volumes"
run_wrapper -ls true -it enterprise -di onlyoffice/documentserver-ee -dv 9.1.0 -skiphc true --licensepath "${WORK_DIR}/license.lic"
expect_rc 0
expect_log "-v onlyoffice_docs_db:/var/lib/postgresql"
expect_log "-v onlyoffice_docs_rabbitmq:/var/lib/rabbitmq"
expect_log "-v onlyoffice_docs_redis:/var/lib/redis"
[ -f "${SCENARIO_HOME}/onlyoffice/DocumentServer/data/license.lic" ] || fail "the license was not installed"
end_scenario

new_scenario "An update finds the directory of a custom --basedir"
run_wrapper -ls true -it community -dv 9.1.0 -skiphc true -bd "${WORK_DIR}/custom/onlyoffice"
expect_rc 0
[ -d "${WORK_DIR}/custom/onlyoffice/DocumentServer/data" ] || fail "the custom base directory was not used"
: > "${FAKE_DOCKER_STATE}/docker.log"
run_wrapper -ls true -it community -dv 9.1.1 -skiphc true -u true
expect_rc 0
expect_log "-v ${WORK_DIR}/custom/onlyoffice/DocumentServer/data:/var/www/onlyoffice/Data"
[ -e "${SCENARIO_HOME}/onlyoffice" ] && fail "the update created the default directory"
end_scenario

new_scenario "A busy port is detected with the BSD netstat"
# a plain listening socket: http.server of some Python versions leaves the socket shown as CLOSED by netstat
python3 -c "import socket, time; s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind(('0.0.0.0', 8080)); s.listen(5); time.sleep(120)" > /dev/null 2>&1 &
LISTENER_PID=$!
for _ in 1 2 3 4 5; do netstat -an | grep -q '\.8080 .*LISTEN' && break; sleep 1; done
run_wrapper -ls true -it community -dv 9.1.0 -skiphc true -dp 8080
kill "${LISTENER_PID}" 2> /dev/null
expect_rc 1
expect_output "The following TCP Ports must be available: 8080"
expect_no_log "run --net"
end_scenario

new_scenario "Low Docker Desktop resources"
FAKE_DOCKER_MEM=2000000000 FAKE_DOCKER_CPU=1 run_wrapper -ls true -it community -dv 9.1.0
expect_rc 1
expect_output "of RAM (available: 2000 MB)"
expect_output "Settings > Resources"
end_scenario

new_scenario "Running under sudo is refused"
if sudo -n true 2> /dev/null; then
    ( cd "${INSTALL_DIR}" && sudo -n env HOME="${SCENARIO_HOME}" FAKE_DOCKER_STATE="${FAKE_DOCKER_STATE}" PATH="${FAKE_BIN}:${PATH}" \
        bash docs-install.sh -ls true -it community -dv 9.1.0 -skiphc true < /dev/null ) > "${OUT_FILE}" 2>&1
    RC=$?
    expect_rc 1
    expect_output "without sudo"
else
    echo "skipped: sudo is not available"
fi
end_scenario

new_scenario "Uninstall with Docker Desktop stopped starts it and removes the data"
mkdir -p "${SCENARIO_HOME}/onlyoffice/DocumentServer/data"
( cd "${INSTALL_DIR}" && printf 'y\n' | HOME="${SCENARIO_HOME}" FAKE_DOCKER_STATE="${FAKE_DOCKER_STATE}" PATH="${FAKE_BIN}:${PATH}" \
    bash docs-install.sh -ls true -uni true ) > "${OUT_FILE}" 2>&1
RC=$?
expect_rc 0
expect_log "open /Applications/Docker.app"
expect_log "network rm"
[ ! -e "${SCENARIO_HOME}/onlyoffice/DocumentServer" ] || fail "the data directory was not removed"
end_scenario

new_scenario "Uninstall without Docker removes the local files and installs nothing"
if command -v docker > /dev/null 2>&1 || [ -x /Applications/Docker.app/Contents/Resources/bin/docker ]; then
    echo "skipped: Docker is installed on this machine"
else
    # A brew that refuses and records the installation of a cask, everything else goes to the real one
    NO_DOCKER_BIN="${WORK_DIR}/no-docker-bin"
    REAL_BREW=$(PATH="${PATH}:/opt/homebrew/bin:/usr/local/bin" command -v brew)
    mkdir -p "${NO_DOCKER_BIN}" "${SCENARIO_HOME}/onlyoffice/DocumentServer/data"
    printf '#!/bin/bash\ncase "$*" in *--cask*) touch "%s/brew-cask"; exit 1 ;; esac\nexec "%s" "$@"\n' "${FAKE_DOCKER_STATE}" "${REAL_BREW}" > "${NO_DOCKER_BIN}/brew"
    chmod +x "${NO_DOCKER_BIN}/brew"
    ( cd "${INSTALL_DIR}" && printf 'y\n' | HOME="${SCENARIO_HOME}" FAKE_DOCKER_STATE="${FAKE_DOCKER_STATE}" PATH="${NO_DOCKER_BIN}:${PATH}" \
        bash docs-install.sh -ls true -uni true ) > "${OUT_FILE}" 2>&1
    RC=$?
    expect_rc 0
    expect_output "Docker is not installed, only the local files"
    [ ! -e "${FAKE_DOCKER_STATE}/brew-cask" ] || fail "Docker Desktop was installed on uninstall"
    [ ! -e "${SCENARIO_HOME}/onlyoffice/DocumentServer" ] || fail "the data directory was not removed"
fi
end_scenario

echo
if [ "${FAILURES}" -eq 0 ]; then
    echo "All scenarios passed"
else
    echo "${FAILURES} check(s) failed"
    exit 1
fi
