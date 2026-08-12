import http.server
import socketserver
import os
import subprocess
import sys
import threading
import time

PORT = 3000
BACKEND_PORT = 8000
ROOT = os.path.dirname(os.path.abspath(__file__))
BUILD_DIR = os.path.join(ROOT, "build", "web")


class SPAHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=BUILD_DIR, **kwargs)

    def do_GET(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path) or (
            os.path.isdir(path) and not os.path.exists(os.path.join(path, "index.html"))
        ):
            self.path = "/index.html"
        return super().do_GET()

    def log_message(self, format, *args):
        pass


def start_backend():
    subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "backend_api:app",
         "--host", "127.0.0.1", "--port", str(BACKEND_PORT)],
        cwd=os.path.join(ROOT, ".."),
        creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
    )
    print(f"[OK] Backend: http://127.0.0.1:{BACKEND_PORT}")


if __name__ == "__main__":
    print("=" * 50)
    print("  EcoSort - Demarrage")
    print("=" * 50)

    if not os.path.exists(os.path.join(BUILD_DIR, "index.html")):
        print("\n[BUILD] Compilation en cours...")
        subprocess.run(["flutter", "build", "web", "--release"], cwd=ROOT, check=True)

    start_backend()
    time.sleep(1)

    print(f"[OK] Frontend: http://localhost:{PORT}")
    print("=" * 50)
    print("  Ouvrez http://localhost:3000 dans Chrome")
    print("  Ctrl+C pour arreter")
    print("=" * 50)

    with socketserver.TCPServer(("", PORT), SPAHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nArret...")
            httpd.shutdown()
