#!/usr/bin/env python3
"""
Mock HTTP Server for Testing
Configurable via JSON/YAML files to define routes and responses.
"""

import json
import yaml
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import re
import os
import sys
import argparse

class StopMcpServer(BaseException):
    pass


class MockHTTPHandler(BaseHTTPRequestHandler):
    """Handler for mock HTTP requests based on configuration."""
    
    config = {}
    
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
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        query_params = parse_qs(parsed_path.query)

        # If the path is "/stop", the server should exit. Obviously a 
        # little hack, and also obviously only suitable for internal
        # (in this case, test) applications.
        if path == "/stop":
            self.send_response(200)
            self.end_headers()

            raise StopMcpServer("immediately")
        
        # Read request body if present
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8') if content_length > 0 else ''
        content_type = self.headers.get('Content-Type',[])
        if len(body) > 0 and content_type == 'application/json':
            body = json.loads(body)
        # Find matching route
        response = self.find_matching_response(method, path, body)
        
        if response:
            self.send_configured_response(response, path, query_params, body)
        else:
            self.send_404()
    
    def find_response_by_request(self, route, body):
        # Match request by jrpc method or entire body

        if isinstance(body,str):
            for req in route.get('request', []):
                b = req.get('body',[])
                if b == body:
                    return req.get('response',[])
        elif isinstance(body,dict):
            jrpc = body.get('method',[])
            print(jrpc)
            for req in route.get('request', []):
                mth = req.get('jrpc')
                if mth == jrpc:
                    # call must match inputs too
                    if jrpc == "tools/call":
                        call = req.get('call')
                        print(call)
                        actualIn = body.get('params').get('arguments')
                        expectedIn = call.get('input')
                        print(actualIn)
                        print(expectedIn)
                        if expectedIn == actualIn:
                            return req.get('response')
                        else:
                            continue
                    else:
                        return req.get('response')
        return None

    def find_matching_response(self, method, path, body):
        """Find a route configuration that matches the request."""
        for route in self.config.get('routes', []):
            # Check if method matches
            route_methods = route.get('methods', ['GET'])
            if method not in route_methods:
                continue

            # Check if path matches (exact or regex)
            route_path = route.get('path', '')
            if route.get('regex', False):
                if re.match(route_path, path):
                    return self.find_response_by_request(route,body)
            else:
                if route_path == path:
                    return self.find_response_by_request(route,body)
        
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
        
        # Send response
        self.send_response(status_code)
        
        # Send headers
        for header_name, header_value in headers.items():
            self.send_header(header_name, header_value)
        
        self.end_headers()
        
        # Send body
        if response_body:
            self.wfile.write(response_body.encode('utf-8'))
        
        # Log the request
        print(f"{self.command} {path} -> {status_code}")
    
    def send_404(self):
        """Send a 404 response."""
        self.send_response(404)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        error_response = json.dumps({'error': 'Not Found', 'path': self.path})
        self.wfile.write(error_response.encode('utf-8'))
        print(f"{self.command} {self.path} -> 404 (Not Found)")
    
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


def run_server(config_file, host='localhost', port=8080):
    """Run the mock HTTP server."""
    # Load configuration
    config = load_config(config_file)
    MockHTTPHandler.config = config
    
    # Create and start server
    server_address = (host, port)
    httpd = HTTPServer(server_address, MockHTTPHandler)
    
    print(f"Mock HTTP Server running on http://{host}:{port}")
    print(f"Loaded {len(config.get('routes', []))} routes from {config_file}")
    print(f"PID = {os.getpid()}")
    print("Press Ctrl+C to stop\n")
    
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
    
    args = parser.parse_args()
    
    try:
        run_server(args.config, args.host, args.port)
    except FileNotFoundError:
        print(f"Error: Config file '{args.config}' not found")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
