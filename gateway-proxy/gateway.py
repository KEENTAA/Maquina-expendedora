import http.server
import socketserver
import urllib.request
import urllib.parse
import urllib.error

class GatewayHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.proxy_request('GET')

    def do_HEAD(self):
        self.proxy_request('HEAD')

    def do_POST(self):
        self.proxy_request('POST')

    def do_PUT(self):
        self.proxy_request('PUT')

    def do_DELETE(self):
        self.proxy_request('DELETE')

    def do_PATCH(self):
        self.proxy_request('PATCH')

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.end_headers()

    def proxy_request(self, method):
        path = self.path
        target_port = 5174

        if path.startswith('/p/'):
            parts = path.split('/', 3)
            if len(parts) >= 3 and parts[2].isdigit():
                target_port = int(parts[2])
                path = '/' + (parts[3] if len(parts) > 3 else '')
        elif path == '/unity' or path.startswith('/unity/') or path.startswith('/Build/') or path.startswith('/TemplateData/'):
            target_port = 8060
            if path == '/unity':
                path = '/'
            elif path.startswith('/unity/'):
                path = path[6:]  # strip '/unity'
        elif path.startswith('/api/v1/machines/provisioning') or path.startswith('/api/v1/machines') or path.startswith('/api/v1/settings'):
            target_port = 8040
        elif path.startswith('/api/v1/transactions') or path.startswith('/api/v1/admin') or path.startswith('/init/'):
            target_port = 8010
        elif path.startswith('/api/v1/auth'):
            target_port = 8030
        elif path.startswith('/api/'):
            target_port = 5174
        elif '_port=' in path:
            parsed = urllib.parse.urlparse(path)
            qs = urllib.parse.parse_qs(parsed.query)
            if '_port' in qs and qs['_port'][0].isdigit():
                target_port = int(qs['_port'][0])
                del qs['_port']
                new_q = urllib.parse.urlencode(qs, doseq=True)
                path = parsed.path + (('?' + new_q) if new_q else '')
        else:
            # Todas las demás rutas web (/crm, /, /login, /wallet, /signup, etc.) van al frontend
            target_port = 5174

        target_url = f"http://127.0.0.1:{target_port}{path}"
        
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else None

        req_headers = {}
        for k, v in self.headers.items():
            if k.lower() not in ['host', 'content-length']:
                req_headers[k] = v

        req = urllib.request.Request(target_url, data=body, headers=req_headers, method=method)

        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                resp_body = resp.read()
                self.send_response(resp.status)
                for h, val in resp.getheaders():
                    if h.lower() not in ['transfer-encoding', 'content-length']:
                        self.send_header(h, val)
                self.send_header('Content-Length', str(len(resp_body)))
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(resp_body)
        except urllib.error.HTTPError as e:
            err_body = e.read()
            self.send_response(e.code)
            for h, val in e.headers.items():
                if h.lower() not in ['transfer-encoding', 'content-length']:
                    self.send_header(h, val)
            self.send_header('Content-Length', str(len(err_body)))
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(err_body)
        except Exception as e:
            self.send_response(502)
            msg = f"Gateway Error connecting to {target_url}: {e}".encode()
            self.send_header('Content-Type', 'text/plain')
            self.send_header('Content-Length', str(len(msg)))
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(msg)

if __name__ == '__main__':
    PORT = 8090
    http.server.ThreadingHTTPServer.allow_reuse_address = True
    with http.server.ThreadingHTTPServer(("", PORT), GatewayHandler) as httpd:
        print(f"GROG API Gateway running (multithreaded) on port {PORT}")
        httpd.serve_forever()
