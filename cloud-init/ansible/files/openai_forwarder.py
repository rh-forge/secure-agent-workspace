#!/usr/bin/env python3
import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
    "host",
    "authorization",
}


def env(name, default=""):
    return os.environ.get(name, default)


def provider_key():
    key_file = env("OPENAI_API_KEY_FILE")
    if key_file:
        try:
            with open(key_file, encoding="utf-8") as handle:
                return handle.read()
        except OSError:
            return ""
    return env("OPENAI_API_KEY")


EXPECTED_BEARER = env("INTEGRATION_PROXY_EXPECTED_BEARER")
UPSTREAM_BASE = env("OPENAI_UPSTREAM_BASE_URL", "https://api.openai.com/v1").rstrip("/")
PORT = int(env("INTEGRATION_PROXY_PORT", "18083"))
TLS_CERT = env("INTEGRATION_PROXY_TLS_CERT", "/etc/saw-integration/tls/server.crt")
TLS_KEY = env("INTEGRATION_PROXY_TLS_KEY", "/etc/saw-integration/tls/server.key")


class ProxyHandler(BaseHTTPRequestHandler):
    server_version = "saw-openai-forwarder/0.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def send_json(self, status, payload):
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/healthz":
            self.send_json(200, {"status": "ok"})
            return
        if self.path == "/readyz":
            if provider_key():
                self.send_json(200, {"status": "ready"})
            else:
                self.send_json(503, {"status": "provider-not-ready"})
            return
        if self.path.startswith("/v1/"):
            self.forward()
            return
        self.send_json(404, {"error": "not-found"})

    def do_POST(self):
        if self.path.startswith("/v1/"):
            self.forward()
            return
        self.send_json(404, {"error": "not-found"})

    def do_DELETE(self):
        if self.path.startswith("/v1/"):
            self.forward()
            return
        self.send_json(404, {"error": "not-found"})

    def do_PATCH(self):
        if self.path.startswith("/v1/"):
            self.forward()
            return
        self.send_json(404, {"error": "not-found"})

    def read_body(self):
        length = int(self.headers.get("content-length", "0"))
        if length <= 0:
            return None
        return self.rfile.read(length)

    def auth_status(self):
        header = self.headers.get("authorization", "")
        prefix = "Bearer "
        if not header.startswith(prefix):
            return 401
        token = header[len(prefix) :]
        if not EXPECTED_BEARER or token != EXPECTED_BEARER:
            return 403
        return 200

    def upstream_url(self):
        suffix = self.path[len("/v1") :]
        if not suffix:
            suffix = "/"
        return UPSTREAM_BASE + suffix

    def forward(self):
        auth_status = self.auth_status()
        if auth_status == 401:
            self.send_json(401, {"error": "missing-bearer"})
            return
        if auth_status == 403:
            self.send_json(403, {"error": "invalid-bearer"})
            return
        current_provider_key = provider_key()
        if not current_provider_key:
            self.send_json(503, {"status": "provider-not-ready"})
            return

        body = self.read_body()
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in HOP_BY_HOP_HEADERS
        }
        headers["authorization"] = f"Bearer {current_provider_key}"
        headers["host"] = urllib.parse.urlparse(UPSTREAM_BASE).netloc

        request = urllib.request.Request(
            self.upstream_url(),
            data=body,
            headers=headers,
            method=self.command,
        )

        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                response_body = response.read()
                self.send_response(response.status)
                self.copy_response_headers(response.headers, len(response_body))
                self.end_headers()
                self.wfile.write(response_body)
        except urllib.error.HTTPError as exc:
            response_body = exc.read()
            self.send_response(exc.code)
            self.copy_response_headers(exc.headers, len(response_body))
            self.end_headers()
            self.wfile.write(response_body)
        except urllib.error.URLError as exc:
            self.send_json(502, {"error": "upstream-unavailable", "reason": str(exc.reason)})

    def copy_response_headers(self, headers, length):
        for key, value in headers.items():
            if key.lower() in HOP_BY_HOP_HEADERS or key.lower() == "content-length":
                continue
            self.send_header(key, value)
        self.send_header("content-length", str(length))


def main():
    if not EXPECTED_BEARER:
        print("INTEGRATION_PROXY_EXPECTED_BEARER is required", file=sys.stderr)
        return 2

    server = ThreadingHTTPServer(("0.0.0.0", PORT), ProxyHandler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certfile=TLS_CERT, keyfile=TLS_KEY)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    print(f"listening on https://0.0.0.0:{PORT}", file=sys.stderr)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
