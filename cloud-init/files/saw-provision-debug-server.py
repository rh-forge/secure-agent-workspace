#!/usr/bin/env python3
import html
import re
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOG_PATH = "/var/log/saw-provision.log"


def command_output(args):
    try:
        return subprocess.run(
            args,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=20,
        ).stdout
    except Exception as exc:
        return f"{type(exc).__name__}: {exc}\n"


def redact(text):
    text = re.sub(
        r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----",
        "<redacted private key>",
        text,
        flags=re.S,
    )
    text = re.sub(r"sk-[A-Za-z0-9_-]+", "sk-<redacted>", text)
    return re.sub(
        r"(?im)^([A-Za-z0-9_.-]*(?:api[_-]?key|token|password|secret)[A-Za-z0-9_.-]*\s*[:=]\s*).*$",
        r"\1<redacted>",
        text,
    )


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/healthz", "/readyz"):
            body = "ok\n"
        elif self.path == "/status":
            body = command_output(["/usr/bin/systemctl", "status", "saw-provision.service", "--no-pager", "-l"])
        elif self.path == "/journal":
            body = command_output(["/usr/bin/journalctl", "-u", "saw-provision.service", "-n", "260", "--no-pager"])
        elif self.path == "/log":
            body = command_output(["/usr/bin/tail", "-n", "420", LOG_PATH])
        else:
            body = "saw provision diagnostics\n\nGET /healthz\nGET /status\nGET /journal\nGET /log\n"
        payload = html.escape(redact(body)).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        return


ThreadingHTTPServer(("0.0.0.0", 18080), Handler).serve_forever()
