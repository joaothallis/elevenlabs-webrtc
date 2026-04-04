#!/usr/bin/env python3
"""
Tiny HTTP proxy that bridges Hex package registry requests.

Erlang's httpc can't properly handle TLS through the Anthropic HTTPS
proxy (TLS interception). This server listens on localhost:8888 (HTTP)
and forwards requests to repo.hex.pm using Python's urllib, which
handles the HTTPS proxy correctly via system TLS.

Usage:
    python3 hex_proxy.py
    # Then set HEX_MIRROR_URL=http://127.0.0.1:8888
"""
import http.server
import urllib.request
import urllib.error
import sys

PORT = 8888
TARGET = "https://repo.hex.pm"


class HexProxy(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        url = TARGET + self.path
        try:
            req = urllib.request.Request(url)
            req.add_header("User-Agent", "HexProxy/1.0")
            with urllib.request.urlopen(req, timeout=30) as resp:
                body = resp.read()
                self.send_response(resp.getcode())
                for key, val in resp.getheaders():
                    if key.lower() not in ("transfer-encoding", "connection"):
                        self.send_header(key, val)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def log_message(self, format, *args):
        pass  # silence request logs


if __name__ == "__main__":
    server = http.server.HTTPServer(("127.0.0.1", PORT), HexProxy)
    print(f"Hex proxy on http://127.0.0.1:{PORT}", flush=True)
    server.serve_forever()
