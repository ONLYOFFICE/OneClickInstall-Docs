import os
import re
import time
import urllib.error
import urllib.request

import pytest
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.action_chains import ActionChains
from selenium.common.exceptions import TimeoutException, WebDriverException

SERVER_URL = os.environ.get('SERVER_URL', 'http://localhost').rstrip('/')
TEST_TEXT = "Test text for editor verification"

# Readiness by DOM state; isDocumentLoadComplete only when the build exports it (EE strips it)
LOAD_COMPLETE_JS = ("var api = window.editor || (window.Asc && window.Asc.editor);"
                    " var sdk = document.getElementById('editor_sdk');"
                    " return document.readyState === 'complete' && !!api"
                    " && !document.querySelector('.loadmask, .asc-loadmask')"
                    " && !!(sdk && sdk.children.length)"
                    " && (api.isDocumentLoadComplete === undefined"
                    "     || api.isDocumentLoadComplete === true)")

# asc_isDocumentModified is not exported in EE builds — degrade to a no-op there
NOT_MODIFIED_JS = ("var api = window.editor || (window.Asc && window.Asc.editor);"
                   " return api && api.asc_isDocumentModified"
                   " ? !api.asc_isDocumentModified() : true")

# ANSI color codes
GREEN = '\033[92m'
RED = '\033[91m'
BLUE = '\033[94m'
YELLOW = '\033[93m'
RESET = '\033[0m'

def step(message):
    """Open a one-line progress entry; close it with done()/skip()/fail()."""
    print(f"{BLUE}  → {message}{RESET} ... ", end='', flush=True)

def done(note='ok'):
    print(f"{GREEN}{note}{RESET}")

@pytest.fixture(autouse=True)
def _start_progress_block():
    """Start test output on a fresh line after the pytest test id."""
    print(flush=True)
    yield

def skip(note):
    print(f"{YELLOW}{note}{RESET}")

def fail(note):
    print(f"{RED}{note}{RESET}")

def print_info(message):
    print(f"{BLUE}  {message}{RESET}")

def http_get(path, timeout=10):
    request = urllib.request.Request(SERVER_URL + path, headers={'User-Agent': 'docs-smoke-test'})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()

def make_driver():
    chrome_options = Options()
    chrome_options.add_argument('--headless')
    chrome_options.add_argument('--no-sandbox')
    chrome_options.add_argument('--disable-dev-shm-usage')
    chrome_options.add_argument('--window-size=1920,1080')
    # capture the browser console so editor-load timeouts can show the actual JS error
    chrome_options.set_capability('goog:loggingPrefs', {'browser': 'ALL'})

    # Remote WebDriver (e.g. selenium/standalone-chromium container on ARM)
    remote_url = os.environ.get('SELENIUM_REMOTE_URL')
    if remote_url:
        return webdriver.Remote(command_executor=remote_url, options=chrome_options)

    # Optional explicit paths; runner images may export a stale CHROME_BIN, so verify it exists
    chrome_bin = os.environ.get('CHROME_BIN')
    if chrome_bin and os.path.isfile(chrome_bin):
        chrome_options.binary_location = chrome_bin

    chromedriver_path = os.environ.get('CHROMEDRIVER_PATH')
    service = Service(chromedriver_path) if chromedriver_path else None

    return webdriver.Chrome(service=service, options=chrome_options)

def dump_page_state(driver):
    """Print debug info that explains a missing editor iframe."""
    print_info(f"Current URL: {driver.current_url}")
    try:
        state = driver.execute_script(
            "return {readyState: document.readyState,"
            " docsApi: typeof window.DocsAPI,"
            " iframes: document.getElementsByTagName('iframe').length,"
            " scripts: [].map.call(document.scripts, function(s){return s.src;}).filter(Boolean)}")
        print_info(f"Page state: {state}")
    except WebDriverException as e:
        print_info(f"Could not collect page state: {e}")
    try:
        print_info("Browser console (last 30 entries):")
        for entry in driver.get_log('browser')[-30:]:
            print(f"  [{entry.get('level')}] {entry.get('message')}")
    except WebDriverException as e:
        print_info(f"Could not collect browser console: {e}")
    print_info("Current page source:")
    print(driver.page_source[:1000])

def dismiss_dialogs(driver):
    """Close modal dialogs that may cover the editor (e.g. notices on first open)."""
    for _ in range(5):
        buttons = [b for b in driver.find_elements(By.CSS_SELECTOR, "button.dlg-btn[result='ok']")
                   if b.is_displayed()]
        if not buttons:
            return
        # dialogs may stack — the last one is on top and intercepts clicks
        button = buttons[-1]
        text = driver.execute_script(
            "var w = arguments[0].closest('.asc-window'); return w ? w.innerText : '';", button)
        step(f"Dismissing dialog: {' '.join(text.split())[:120]!r}")
        driver.execute_script("arguments[0].click();", button)
        time.sleep(1)
        done("closed")

def wait_for_js(driver, script, timeout, description):
    """Poll a JS condition inside the current frame until it returns true."""
    step(description)
    start = time.time()
    while time.time() - start < timeout:
        try:
            if driver.execute_script(script):
                done(f"done in {time.time() - start:.1f}s")
                return
        except WebDriverException:
            pass
        time.sleep(1)
    fail(f"timeout after {timeout}s")
    raise TimeoutException(f"Timed out waiting for {description}")

def wait_editor_loaded(driver, attempts=3, editor_timeout=30):
    """Enter the editor iframe and wait until the document renders;
    a stuck editor never recovers on its own — reload between short waits."""
    for attempt in range(1, attempts + 1):
        if attempt > 1:
            driver.refresh()
        step("Editor iframe" + (f" (attempt {attempt})" if attempt > 1 else ""))
        WebDriverWait(driver, 60).until(
            EC.frame_to_be_available_and_switch_to_it((By.TAG_NAME, "iframe")))
        done()

        step("Loading document in the editor")
        start = time.time()
        while time.time() - start < editor_timeout:
            try:
                if driver.execute_script(LOAD_COMPLETE_JS):
                    done(f"done in {time.time() - start:.1f}s")
                    return
            except WebDriverException:
                pass
            time.sleep(1)
        fail(f"not loaded within {editor_timeout}s" + (", reloading" if attempt < attempts else ""))
        driver.switch_to.default_content()
    raise TimeoutException(f"Editor did not load in {attempts} attempts of {editor_timeout}s")

def test_healthcheck():
    """Core services must answer the healthcheck endpoint with "true"."""
    step(f"GET {SERVER_URL}/healthcheck")
    deadline = time.time() + 60
    status, body = None, b''
    while time.time() < deadline:
        try:
            status, body = http_get('/healthcheck')
        except (urllib.error.URLError, OSError) as e:
            status, body = None, str(e).encode()
        if status == 200 and body.strip() == b'true':
            done()
            return
        print('.', end='', flush=True)
        time.sleep(5)
    fail(f"HTTP {status}: {body[:200]!r}")
    raise AssertionError(f"Healthcheck failed: HTTP {status}, body: {body[:200]!r}")

def test_api_js():
    """Integration API script must be served — it is what real integrations load."""
    step(f"GET {SERVER_URL}/web-apps/apps/api/documents/api.js")
    status, body = http_get('/web-apps/apps/api/documents/api.js')
    if status != 200 or b'DocsAPI' not in body:
        fail(f"HTTP {status}")
    assert status == 200, f"api.js request failed: HTTP {status}"
    assert b'DocsAPI' in body, "api.js content does not define DocsAPI"
    done(f"{len(body)} bytes")

def test_version_info():
    """DocService must report its version; with EXPECTED_VERSION set it must match (update CI)."""
    step(f"GET {SERVER_URL}/index.html")
    status, body = http_get('/index.html')
    text = body.decode('utf-8', 'replace').strip()
    # Customer Id identifies the real license (when one is installed) — never print it, CI logs are public
    safe_text = re.sub(r'Customer Id: [^.]*\.', 'Customer Id: [redacted].', text)
    if status != 200 or 'Server is functioning normally' not in text:
        fail(f"HTTP {status}: {safe_text[:200]!r}")
    assert status == 200 and 'Server is functioning normally' in text, \
        f"Unexpected /index.html response: HTTP {status}, body: {safe_text[:200]!r}"

    expected_version = os.environ.get('EXPECTED_VERSION')
    if expected_version and f"Version: {expected_version}." not in text:
        fail(f"expected version {expected_version}, got: {safe_text[:120]}")
    assert not expected_version or f"Version: {expected_version}." in text, \
        f"Expected version {expected_version}, got: {safe_text[:200]!r}"
    done(safe_text)

def test_adminpanel():
    """Admin panel must respond when shipped: 404 skips (not shipped, e.g. CE Docker)
    unless CHECK_ADMINPANEL=true (DEB/RPM always ship it); 502 etc. fails."""
    strict = os.environ.get('CHECK_ADMINPANEL', '').lower() == 'true'
    step(f"GET {SERVER_URL}/admin/")
    status, body = http_get('/admin/')
    if status == 404 and not strict:
        skip("skipped — not shipped with this installation (HTTP 404)")
        pytest.skip("Admin panel is not shipped with this installation (HTTP 404)")
    if status != 200 or not body.strip():
        fail(f"HTTP {status}")
    assert status == 200 and body.strip(), f"Admin panel did not respond: HTTP {status}"
    done(f"{len(body)} bytes")

def test_document_editor():
    """Full user scenario: welcome page -> example -> open, edit and save a document."""
    driver = make_driver()
    wait = WebDriverWait(driver, 30)

    try:
        step("Welcome page")
        driver.get(SERVER_URL)
        done(driver.current_url)

        step("Test example button")
        wait.until(EC.element_to_be_clickable((By.XPATH, "//a[contains(@href, 'example')]"))).click()
        done("clicked")

        step("Editor link")
        wait.until(EC.element_to_be_clickable((By.XPATH, "//a[contains(@href, 'editor')]"))).click()
        done("clicked")

        # The editor opens in a new window
        step("Editor window")
        wait.until(lambda d: len(d.window_handles) > 1)
        driver.switch_to.window(driver.window_handles[-1])
        assert "editor" in driver.current_url, f"Invalid URL: {driver.current_url}"
        done(driver.current_url)

        # The editor itself lives in an iframe created by api.js
        wait_editor_loaded(driver)
        time.sleep(3)
        dismiss_dialogs(driver)

        step("Typing test text")
        wait.until(EC.presence_of_element_located((By.ID, "editor_sdk"))).click()
        ActionChains(driver).send_keys(TEST_TEXT).perform()
        time.sleep(2)
        done()

        # Select all and read the text back through the editor API
        step("Verifying the text reached the document")
        ActionChains(driver).key_down(Keys.CONTROL).send_keys('a').key_up(Keys.CONTROL).perform()
        time.sleep(1)
        selected = driver.execute_script(
            "return window.editor.asc_GetSelectedText ? window.editor.asc_GetSelectedText() : null")
        if not (selected and TEST_TEXT in selected):
            fail(f"not found (selection: {selected!r})")
        assert selected and TEST_TEXT in selected, \
            f"Typed text not found in the document (selection: {selected!r})"
        done("found")

        # Save and wait until the editor reports no unsaved changes
        ActionChains(driver).key_down(Keys.CONTROL).send_keys('s').key_up(Keys.CONTROL).perform()
        wait_for_js(driver, NOT_MODIFIED_JS, 30, "Saving document (Ctrl+S)")

    except Exception as e:
        print(flush=True)
        fail(f"Test failed: {e}")
        dump_page_state(driver)
        raise
    finally:
        driver.quit()

@pytest.mark.parametrize('file_ext', ['xlsx', 'pptx', 'pdf'])
def test_create_new_document(file_ext):
    """Each editor type must create and render a new empty document
    (docx is covered by test_document_editor)."""
    driver = make_driver()

    try:
        step(f"New {file_ext}: opening {SERVER_URL}/example/editor?fileExt={file_ext}")
        driver.get(f"{SERVER_URL}/example/editor?fileExt={file_ext}")
        done()
        wait_editor_loaded(driver)
    except Exception as e:
        print(flush=True)
        fail(f"{file_ext} editor failed: {e}")
        dump_page_state(driver)
        raise
    finally:
        driver.quit()

def test_download():
    """A stored document must be downloadable back from the example storage."""
    step(f"GET {SERVER_URL}/example/")
    status, body = http_get('/example/')
    assert status == 200, f"Example page failed: HTTP {status}"
    match = re.search(r'download\?fileName=([^"&]+)', body.decode('utf-8', 'replace'))
    assert match, "No stored files with a download link found on the example page"
    done()

    file_name = match.group(1)
    step(f"Download {file_name}")
    status, body = http_get(f'/example/download?fileName={file_name}')
    if status != 200 or not body:
        fail(f"HTTP {status}")
    assert status == 200 and body, f"Download failed: HTTP {status}"
    assert body[:2] == b'PK' or body[:4] == b'%PDF', \
        f"Downloaded file is neither OOXML nor PDF (starts with {body[:4]!r})"
    done(f"{len(body)} bytes")
