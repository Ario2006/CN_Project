#!/usr/bin/env python3
"""Minimal REST backend for the CN project (the network is the project, not this app).
Subnet: 10.7.0.0/19 | Netmask: 255.255.224.0 (0xffffe000) | Gateway: 10.7.0.1
Hosts:
  Backend A (Mac 3, Abhijeet): 10.7.2.73:3001  | Air MAC: 8e:c9:23:39:6e:c1 | HW MAC: 10:9f:41:c0:b2:b1
  Backend B (Mac 4, Ankita)  : 10.7.5.46:3002  | Air MAC: da:8e:64:df:05:3f | HW MAC: 10:9f:41:c6:2a:38
Env: BACKEND_ID (A/B), PORT (3001/3002), BIND (default 0.0.0.0 = all interfaces, LAN reachable)."""
import json
import os
import socket
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BACKEND_ID = os.environ.get("BACKEND_ID", "A")
PORT = int(os.environ.get("PORT", "3001"))
BIND = os.environ.get("BIND", "0.0.0.0")
ETAG = '"phase1-cache-v1"'


def make_response(path, if_none_match):
    """Return (status, extra_headers, body_dict_or_None)."""
    if path == "/":
        return 200, {"Cache-Control": "no-store"}, {
            "backend": BACKEND_ID, "status": "ok",
            "message": f"Backend {BACKEND_ID} is running",
            "hostname": socket.gethostname(), "port": PORT}
    if path == "/api/status":
        return 200, {"Cache-Control": "no-store"}, {"backend": BACKEND_ID, "status": "ok"}
    if path == "/api/cache":
        headers = {"Cache-Control": "max-age=60", "ETag": ETAG}
        tags = [t.strip() for t in (if_none_match or "").split(",")]
        if "*" in tags or ETAG in tags or ("W/" + ETAG) in tags:
            return 304, headers, None          # conditional request: validator matches
        # Body is IDENTICAL on A and B (same ETag must mean same bytes).
        return 200, headers, {"resource": "cacheable", "version": "phase1-cache-v1"}
    return 404, {"Cache-Control": "no-store"}, {"error": "not found", "backend": BACKEND_ID}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "CNBackend"

    def _handle(self, send_body):
        path = self.path.split("?", 1)[0]
        status, headers, body = make_response(path, self.headers.get("If-None-Match"))
        payload = (json.dumps(body) + "\n").encode() if body is not None else b""
        self.send_response(status)
        self.send_header("X-Backend", BACKEND_ID)
        for k, v in headers.items():
            self.send_header(k, v)
        if body is not None:
            self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if send_body and status != 304:
            self.wfile.write(payload)

    def do_GET(self):
        self._handle(True)

    def do_HEAD(self):
        self._handle(False)

    def log_message(self, fmt, *args):
        # shows the CLIENT socket (for the nginx hop: nginx IP + its ephemeral port)
        print(f"[Backend {BACKEND_ID}:{PORT}] from {self.client_address[0]}:{self.client_address[1]}  {fmt % args}",
              flush=True)


if __name__ == "__main__":
    srv = ThreadingHTTPServer((BIND, PORT), Handler)
    print(f"Backend {BACKEND_ID} listening on {BIND}:{PORT}  (Ctrl+C to stop)", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped", flush=True)
