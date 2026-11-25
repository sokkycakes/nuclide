#!/usr/bin/env python3
"""Local stand-in for GitHub release downloads, for tests.

GET /OWNER/REPO/releases/download/TAG/NAME  -> 302 to /cdn/TAG/NAME (like github.com does)
GET /cdn/TAG/NAME                           -> the file from ROOT/TAG/NAME, with Range support

Every served byte is counted; GET /stats reads the counters and GET /reset-stats
clears them, so tests can check that an update only downloaded what changed.
"""
import argparse
import http.server
import json
import os
import re
import threading
import time

LOCK = threading.Lock()
STATS = {'requests': 0, 'bytes': 0, 'ranges': 0}


class H(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    root = '.'
    rate = 0

    def log_message(self, *a):
        pass

    def do_GET(self):
        path = self.path.split('?')[0]
        if path in ('/stats', '/reset-stats'):
            with LOCK:
                if path == '/reset-stats':
                    STATS.update(requests=0, bytes=0, ranges=0)
                body = json.dumps(STATS).encode()
            self.send_response(200)
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        m = re.match(r'^/[^/]+/[^/]+/releases/download/([^/]+)/([^/]+)$', path)
        if m:
            self.send_response(302)
            self.send_header('Location', f'/cdn/{m.group(1)}/{m.group(2)}?sig=x')
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        m = re.match(r'^/cdn/([^/]+)/([^/]+)$', path)
        if not m or '..' in path:
            return self.fail(404)
        fp = os.path.join(self.root, m.group(1), m.group(2))
        if not os.path.isfile(fp):
            return self.fail(404)
        size = os.path.getsize(fp)
        start, end = 0, size - 1
        rng = self.headers.get('Range')
        status = 200
        if rng:
            r = re.match(r'bytes=(\d+)-(\d*)', rng)
            if not r:
                return self.fail(416)
            start = int(r.group(1))
            end = int(r.group(2)) if r.group(2) else size - 1
            end = min(end, size - 1)
            if start > end:
                return self.fail(416)
            status = 206
        n = end - start + 1
        self.send_response(status)
        self.send_header('Content-Type', 'application/octet-stream')
        self.send_header('Content-Length', str(n))
        self.send_header('Accept-Ranges', 'bytes')
        if status == 206:
            self.send_header('Content-Range', f'bytes {start}-{end}/{size}')
        self.end_headers()
        with LOCK:
            STATS['requests'] += 1
            STATS['ranges'] += 1 if status == 206 else 0
        with open(fp, 'rb') as f:
            f.seek(start)
            left = n
            t0 = time.time()
            sent = 0
            while left > 0:
                c = f.read(min(left, 65536))
                if not c:
                    break
                try:
                    self.wfile.write(c)
                except (BrokenPipeError, ConnectionResetError):
                    return
                left -= len(c)
                sent += len(c)
                with LOCK:
                    STATS['bytes'] += len(c)
                if self.rate:
                    ahead = sent / self.rate - (time.time() - t0)
                    if ahead > 0:
                        time.sleep(ahead)

    def fail(self, code):
        self.send_response(code)
        self.send_header('Content-Length', '0')
        self.end_headers()



def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('root')
    ap.add_argument('--port', type=int, default=8765)
    ap.add_argument('--rate', type=float, default=0, help='bytes/second per connection, 0 = unlimited')
    a = ap.parse_args()
    H.root = a.root
    H.rate = a.rate
    s = http.server.ThreadingHTTPServer(('127.0.0.1', a.port), H)
    s.daemon_threads = True
    print(f'serving {a.root} on http://127.0.0.1:{a.port}', flush=True)
    s.serve_forever()


if __name__ == '__main__':
    main()
