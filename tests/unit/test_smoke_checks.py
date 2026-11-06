"""Run with the smoke requirements installed: python -m pytest tests/unit -q."""
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess

import pytest


ROOT = Path(__file__).resolve().parents[2]
BASH = shutil.which('bash')
spec = importlib.util.spec_from_file_location('docs_smoke', ROOT / 'tests/smoke/test_docs_smoke.py')
browser = importlib.util.module_from_spec(spec)
spec.loader.exec_module(browser)


def run_shell(script, **env):
    if not BASH:
        pytest.skip('Bash is required')
    return subprocess.run([BASH, '--noprofile', '--norc', '-c',
                           'source tests/vagrant/post-install.sh\nget_colors\n' + script],
                          cwd=ROOT, env={**os.environ, **env}, text=True,
                          capture_output=True, timeout=10)


PACKAGE_STUB = r'''
dpkg-query() {
  [ "${!#}" = "$MOCK_PACKAGE" ] || return 1
  case "$1" in -W) echo 'install ok installed' ;; -L) echo "$MOCK_FILES" ;; esac
}
rpm() {
  [ "${!#}" = "$MOCK_PACKAGE" ] || return 1
  if [ "$1" = -ql ]; then echo "$MOCK_FILES"; fi
}
command() {
  if [ "$1" = -v ] && [ "$2" = dpkg-query ] && [ "$MOCK_TYPE" = rpm ]; then return 1; fi
  builtin command "$@"
}
'''


@pytest.mark.parametrize('package_type', ['deb', 'rpm'])
@pytest.mark.parametrize('suffix,manifest,edition,admin', [
    ('', '', 'community', 'false'),
    ('', '/lib/systemd/system/ds-adminpanel.service', 'community', 'true'),
    ('-ee', '', 'enterprise', 'true'),
    ('-de', '', 'developer', 'true'),
])
def test_package_edition_and_legacy_panel(package_type, suffix, manifest, edition, admin):
    result = run_shell(PACKAGE_STUB + '\npackage_info\nprintf "%s|%s" "$DOCS_EDITION" "$DOCS_ADMINPANEL"',
                       MOCK_PACKAGE='onlyoffice-documentserver' + suffix,
                       MOCK_FILES=manifest, MOCK_TYPE=package_type)
    assert result.returncode == 0, result.stderr
    assert result.stdout == f'{edition}|{admin}'


@pytest.mark.parametrize('package', ['not-installed', 'onlyoffice-documentserver'])
def test_missing_package_or_wrong_edition_fails(package):
    result = run_shell(PACKAGE_STUB + '\nmain healthcheck enterprise',
                       MOCK_PACKAGE=package, MOCK_FILES='', MOCK_TYPE='deb')
    assert result.returncode == 1


@pytest.mark.parametrize('admin,disabled,success', [
    ('false', '', True), ('true', '', False), ('false', 'is-enabled', False),
])
def test_missing_panel_and_disabled_autostart(admin, disabled, success):
    result = run_shell('''
DOCS_ADMINPANEL=$MOCK_ADMIN
systemctl() { [[ "${!#}" != ds-adminpanel.service && "$1" != "$MOCK_DISABLED" ]]; }
healthcheck_systemd_services
''', MOCK_ADMIN=admin, MOCK_DISABLED=disabled)
    assert (result.returncode == 0) == success, result.stdout + result.stderr


@pytest.mark.parametrize('admin,status,success', [('true', '404', False), ('true', '200', True), ('false', '404', True)])
def test_native_panel_http_response(admin, status, success):
    result = run_shell('''
DOCS_ADMINPANEL=$MOCK_ADMIN
curl() { printf '%s' "$MOCK_HTTP_STATUS"; }
healthcheck_adminpanel
''', MOCK_ADMIN=admin, MOCK_HTTP_STATUS=status)
    assert (result.returncode == 0) == success, result.stdout + result.stderr


@pytest.mark.parametrize('edition,expectation,status,outcome', [
    ('community', 'false', 404, pytest.skip.Exception),
    ('community', 'true', 404, AssertionError),
    ('enterprise', '', 404, AssertionError),
    ('enterprise', 'false', 404, pytest.skip.Exception),
    ('developer', '', 404, AssertionError),
    ('developer', 'false', 404, pytest.skip.Exception),
    ('', '', 404, pytest.skip.Exception),  # Docker does not set a native edition.
    ('', '', 502, AssertionError),
    ('community', 'false', 502, AssertionError),
    ('enterprise', '', 200, None),
    ('enterprise', 'false', 200, None),
    ('community', 'true', 200, None),
])
def test_browser_panel_response(monkeypatch, edition, expectation, status, outcome):
    monkeypatch.setenv('INSTALLATION_TYPE', edition)
    monkeypatch.setenv('CHECK_ADMINPANEL', expectation)
    monkeypatch.setattr(browser, 'http_get', lambda path: (status, b'panel'))
    if outcome:
        with pytest.raises(outcome):
            browser.test_adminpanel()
    else:
        browser.test_adminpanel()
