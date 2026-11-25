#!/usr/bin/env python3
"""
Mock HTTP Server for Testing
Configurable via JSON/YAML files to define routes and responses.
"""

# Copyright 2026 The MathWorks, Inc.

import json
import yaml
from http.server import HTTPServer, ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import re
import threading
import os
import sys
import argparse
import logging

class StopMcpServer(BaseException):
    pass

class MockHTTPHandler(BaseHTTPRequestHandler):
    """Handler for mock HTTP requests based on configuration."""
    
    config = {}

    # Count of requests received per "METHOD path" key, reported by /stats.
    # Needed to assert that the client does NOT retry a deterministic
    # rejection: a 4xx carrying a JSON-RPC error body will be answered
    # identically every time, so retrying only multiplies the failure. The
    # only way to observe a retry from the outside is to count requests.
    counts = {}

    def do_GET(self):
        self.handle_request('GET')
    
    def do_POST(self):
        self.handle_request('POST')
    
    def do_PUT(self):
        self.handle_request('PUT')
    
    def do_DELETE(self):
        self.handle_request('DELETE')
    
    def do_PATCH(self):
        self.handle_request('PATCH')
    
    def handle_request(self, method):
        """Handle incoming requests based on configuration."""
        logging.debug(f"{method} {self.path}")
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        query_params = parse_qs(parsed_path.query)

        # If the path is "/stop", the server should exit. Obviously a 
        # little hack, and also obviously only suitable for internal
        # (in this case, test) applications.
        if path == "/stop":
            self.send_response(200)
            self.end_headers()

            # A threaded server runs this in a worker thread, where an
            # exception would end only the thread. Shut it down from a
            # thread of its own: shutdown waits for serve_forever to stop.
            if isinstance(self.server, ThreadingHTTPServer):
                threading.Thread(target=self.server.shutdown, daemon=True).start()
                return
            raise StopMcpServer("immediately")

        # Report per-route request counts. Like /stop, a test-only hack, and
        # deliberately not counted itself.
        if path == "/stats":
            payload = json.dumps(MockHTTPHandler.counts).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return

        key = f"{method} {path}"
        MockHTTPHandler.counts[key] = MockHTTPHandler.counts.get(key, 0) + 1

        # MATLAB sends "Expect: 100-continue" with every request that has a
        # body, and waits a second for the server to say go on before
        # sending it. http.server says so only when it speaks HTTP/1.1,
        # which this one doesn't, so every POST cost a second. Say it.
        if self.headers.get('Expect', '').lower() == '100-continue':
            self.wfile.write(b'HTTP/1.1 100 Continue\r\n\r\n')
            self.wfile.flush()

        # Read request body if present
        content_length = int(self.headers.get('Content-Length', 0))
        # An uploaded archive is binary: undecodable bytes must not fail the
        # request, only stop it matching a body.
        body = self.rfile.read(content_length).decode('utf-8', errors='replace') if content_length > 0 else ''
        content_type = self.headers.get('Content-Type',[])
        if len(body) > 0 and content_type == 'application/json':
            body = json.loads(body)
        # Find matching route
        response = self.find_matching_response(method, path, body,
                                               MockHTTPHandler.counts[key])
        
        # A path with a route is an archive that is there: one that has no
        # answer configured for this request says so, with a body, as the
        # framework does. A path with none is an archive that isn't, and
        # gets Production Server's 404, with no body.
        if response:
            self.send_configured_response(response, path, query_params, body)
        elif self.has_route(path):
            self.send_unanswered()
        else:
            self.send_404()

    def has_route(self, path):
        """True if any route, for any method, has this path."""
        for route in self.config.get('routes', []):
            route_path = route.get('path', '')
            if route.get('regex', False):
                if re.match(route_path, path):
                    return True
            elif route_path == path:
                return True
        return False
    
    def find_response_by_request(self, route, method, body, count):
        # Match request by jrpc method or entire body. An entry may also name
        # the HTTP method it answers; one that does not answers any method
        # its route accepts. An entry with "from: N" answers only the Nth
        # and later requests of this method to this path, so a route can
        # change its answer over time; one with "anybody: true" answers any
        # body.
        logging.debug(f"Finding response for {route}")
        requests = [req for req in route.get('request', [])
                    if req.get('method', method) == method
                    and count >= req.get('from', 0)]
        if isinstance(body,str):
            for req in requests:
                logging.debug(body)
                b = req.get('body',[])
                logging.debug(f"b {b}")
                if b == body or req.get('anybody', False):
                    return req.get('response',[])
        elif isinstance(body,dict):
            logging.debug("dict")
            jrpc = body.get('method',[])
            logging.debug(jrpc)
            for req in requests:
                mth = req.get('jrpc')
                if mth == jrpc:
                    # call must match inputs too
                    if jrpc == "tools/call":
                        call = req.get('call')
                        logging.debug(call)
                        actualIn = body.get('params').get('arguments')
                        expectedIn = call.get('input')
                        logging.debug(f"Actual: {actualIn}")
                        logging.debug(f"Expected: {expectedIn}")
                        if expectedIn == actualIn:
                            return req.get('response')
                        else:
                            continue
                    # An entry naming a uri answers only that resource;
                    # one without answers any.
                    elif 'uri' in req:
                        actualUri = (body.get('params') or {}).get('uri')
                        if req.get('uri') == actualUri:
                            return req.get('response')
                        continue
                    else:
                        return req.get('response')
        return None

    def find_matching_response(self, method, path, body, count):
        """Find a route configuration that matches the request."""
        logging.debug(f"Searching for {method} {path}")
        for route in self.config.get('routes', []):
            logging.debug(f"Checking route {route['path']} for {method}")
            # Check if method matches
            route_methods = route.get('methods', ['GET'])
            if method not in route_methods:
                continue

            # Check if path matches (exact or regex)
            route_path = route.get('path', '')
            if route.get('regex', False):
                logging.debug("regex")
                if re.match(route_path, path):
                    return self.find_response_by_request(route,method,body,count)
            else:
                logging.debug(f"exact {route_path} == {path}")
                if route_path == path:
                    return self.find_response_by_request(route,method,body,count)
        
        return None
    
    def send_configured_response(self, response, path, query_params, body):
        """Send response based on route configuration."""
        # Get response configuration
        status_code = response.get('status', 200)
        headers = response.get('headers', {})
        response_body = response.get('body', '')
        
        # Handle dynamic response body
        if isinstance(response_body, dict):
            response_body = json.dumps(response_body)
            if 'Content-Type' not in headers:
                headers['Content-Type'] = 'application/json'
        
        # Add delay if specified
        delay = response.get('delay', 0)
        if delay > 0:
            import time
            time.sleep(delay)
        
        # Send response. "reason" sets the status line's reason phrase,
        # where MATLAB Production Server says why a request failed.
        self.send_response(status_code, response.get('reason'))
        
        # Send headers
        for header_name, header_value in headers.items():
            self.send_header(header_name, header_value)
        
        self.end_headers()
        
        # Send body
        if response_body:
            self.wfile.write(response_body.encode('utf-8'))
        
        # Log the request
        print(f"{self.command} {path} -> {status_code}")

        # "stop: true" stops the server once this response is sent, as
        # /stop does, so every later connection is refused: a server that
        # goes away mid-conversation.
        if response.get('stop', False):
            self.wfile.flush()
            if isinstance(self.server, ThreadingHTTPServer):
                threading.Thread(target=self.server.shutdown, daemon=True).start()
                return
            raise StopMcpServer("after response")
    
    def send_404(self):
        """Send a 404 response as MATLAB Production Server does for an
        archive it doesn't have, or is still deploying: no body. The client
        tells it from the framework's own 404s, which have one."""
        self.send_response(404, 'ComponentNotFound Component not found.')
        self.send_header('Content-Length', '0')
        self.end_headers()
        print(f"{self.command} {self.path} -> 404 (Not Found)")

    def send_unanswered(self):
        """Send a 404 with a body, for a request to a routed path that the
        configuration has no answer for: the archive is there."""
        self.send_response(404)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        error_response = json.dumps({'error': 'Not Found', 'path': self.path})
        self.wfile.write(error_response.encode('utf-8'))
        print(f"{self.command} {self.path} -> 404 (no answer configured)")
    
    def log_message(self, format, *args):
        """Suppress default logging."""
        pass


def load_config(config_file):
    """Load configuration from JSON or YAML file."""
    with open(config_file, 'r') as f:
        if config_file.endswith('.json'):
            return json.load(f)
        elif config_file.endswith('.yaml') or config_file.endswith('.yml'):
            return yaml.safe_load(f)
        else:
            raise ValueError("Config file must be .json, .yaml, or .yml")


def run_server(config_file, host='localhost', port=8080, threaded=False,
               lifetime=900):
    """Run the mock HTTP server. Threaded, it answers requests at the same
    time, so a slow answer doesn't hold up the requests after it. After
    LIFETIME seconds it stops itself (0: never)."""
    # Load configuration
    config = load_config(config_file)
    routes = config.setdefault("routes", [])  # default empty, if none

    # Don't overwrite existing /ping, if any
    if not any(r.get("path") == "/ping" for r in routes):
        # Add a GET /ping to every config -- no body, returns 200
        ping = {
            "path": "/ping",
            "methods": [ "GET" ],
            "request": [{
                "body": "",
                "response": {
                    "status": 200,
                    "headers": {
                        "Content-Type": "text/plain"
                    },
                    "body": "pong"
                }
            }]
        }
        routes.append(ping)
    
    # Attach the loaded routes to the handler class -- the handler reads
    # them from its own "config" class attribute.
    MockHTTPHandler.config = config

    # Create and start server
    server_address = (host, port)
    httpd = (ThreadingHTTPServer if threaded else HTTPServer)(
        server_address, MockHTTPHandler)
    
    print(f"Mock HTTP Server running on http://{host}:{port}")
    print(f"Loaded {len(config.get('routes', []))} routes from {config_file}")
    print("Routes:")
    for route in config.get("routes"):
        print(route["path"])
    print(f"PID = {os.getpid()}")
    print("Press Ctrl+C to stop\n")

    # A test that gave up waiting for the server to start -- Python can take
    # longer than its limit on a busy machine -- sent /stop before anything
    # listened, and the server, once up, ran until someone closed it. No
    # test needs one for long: stop after LIFETIME seconds, whatever.
    if lifetime > 0:
        timer = threading.Timer(lifetime, httpd.shutdown)
        timer.daemon = True
        timer.start()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nCtrl+C shutdown server...")
        httpd.shutdown()
    except StopMcpServer:
        print("\nStop server...")
        httpd.shutdown()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Mock HTTP Server for Testing')
    parser.add_argument('config', help='Path to configuration file (JSON or YAML)')
    parser.add_argument('--host', default='localhost', help='Host to bind to (default: localhost)')
    parser.add_argument('--port', type=int, default=8080, help='Port to bind to (default: 8080)')
    parser.add_argument('--log', nargs="?", const="mock_server.log", default=None, help='Logging on: defaults to mock_server.log')
    parser.add_argument('--threaded', action='store_true', help='Answer requests at the same time, not one after another')
    parser.add_argument('--lifetime', type=float, default=900, help='Seconds before the server stops itself; 0 for never (default: 900)')

    args = parser.parse_args()


    if args.log:
        logging.basicConfig(
            filename=args.log,
            level=logging.DEBUG,
            format="%(asctime)s %(levelname)s %(message)s"
        )
        
    try:
        run_server(args.config, args.host, args.port, args.threaded,
                   args.lifetime)
    except FileNotFoundError:
        print(f"Error: Config file '{args.config}' not found")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
