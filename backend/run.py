"""
VidGrab - PyInstaller Entry Point
No terminal. Double-click = browser opens automatically.
main.py is NOT modified.
"""
import sys
import os
import multiprocessing
import threading
import webbrowser
import time
import socket

multiprocessing.freeze_support()

# ── Redirect stdout/stderr in windowed (no-console) mode ─────────────────────
if getattr(sys, "frozen", False):
    try:
        log_dir = os.path.join(os.path.expanduser("~"), "AppData", "Local", "VidGrab")
        os.makedirs(log_dir, exist_ok=True)
        log_path = os.path.join(log_dir, "vidgrab.log")
        sys.stdout = open(log_path, "w", encoding="utf-8")
        sys.stderr = sys.stdout
    except Exception:
        pass

# ── Path setup ────────────────────────────────────────────────────────────────
if getattr(sys, "frozen", False):
    base_dir = sys._MEIPASS
    backend_dir = os.path.join(base_dir, "backend")
else:
    backend_dir = os.path.dirname(os.path.abspath(__file__))
    base_dir = os.path.dirname(backend_dir)

for p in [backend_dir, base_dir]:
    if p not in sys.path:
        sys.path.insert(0, p)


def wait_for_server(host="127.0.0.1", port=8000, timeout=30):
    """Poll until the server socket is accepting connections."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=0.5):
                return True
        except (ConnectionRefusedError, OSError):
            time.sleep(0.15)
    return False


def open_browser_when_ready():
    """Wait for the server then launch the default browser."""
    if wait_for_server():
        webbrowser.open("http://localhost:8000")


if __name__ == "__main__":
    import uvicorn

    # Launch browser opener in background — it waits until server is up
    threading.Thread(target=open_browser_when_ready, daemon=True).start()

    # Run server in main thread (keeps process alive)
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        log_level="error",   # Suppress verbose logs (no console anyway)
    )
