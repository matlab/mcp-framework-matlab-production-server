# mcpstdio2http.py

# Copyright 2025-2026 The MathWorks, Inc.

import os
import sys
import json
import base64
import logging
import requests
import argparse

# Header names. HTTP header names are case-insensitive; these spellings match
# the server's.
SESSION_ID = 'Mcp-Session-Id'
PROTOCOL_VERSION = 'MCP-Protocol-Version'
MCP_METHOD = 'Mcp-Method'
MCP_NAME = 'Mcp-Name'

# The _meta key a 2026-07-28 request uses to state its protocol revision.
META_PROTOCOL_VERSION = 'io.modelcontextprotocol/protocolVersion'

# Methods whose 2026-07-28 request must carry an Mcp-Name header.
NAMED_METHODS = ('tools/call', 'resources/read', 'prompts/get')

# 2026-07-28 Base64 sentinel for header values that can't travel as-is.
SENTINEL_PREFIX = '=?base64?'
SENTINEL_SUFFIX = '?='

# JSON-RPC code for a request the bridge could not deliver or that came back
# without a JSON-RPC body.
INTERNAL_ERROR = -32603


def single_line(text):
    # The stdio transport requires each message on a single line. Re-serialize
    # compactly; JSON escapes newlines inside strings, so the result has none.
    # Text that isn't JSON is passed through with its line breaks flattened.
    try:
        return json.dumps(json.loads(text), ensure_ascii=False,
                          separators=(',', ':'))
    except ValueError:
        return text.replace('\r', ' ').replace('\n', ' ')


def encode_header_value(value):
    # Mirror of the server's encodeHeaderValue: Base64 the UTF-8 bytes when
    # the value isn't printable ASCII, has leading or trailing whitespace, or
    # already looks like a sentinel.
    needs = (any(ord(c) > 126 or ord(c) < 32 for c in value)
             or value != value.strip()
             or (value.startswith(SENTINEL_PREFIX)
                 and value.endswith(SENTINEL_SUFFIX)))
    if not needs:
        return value
    b64 = base64.b64encode(value.encode('utf-8')).decode('ascii')
    return SENTINEL_PREFIX + b64 + SENTINEL_SUFFIX


def error_response(msg_id, message):
    return json.dumps({'jsonrpc': '2.0', 'id': msg_id,
                       'error': {'code': INTERNAL_ERROR, 'message': message}})


class Bridge:
    # Per-connection state. Under 2025-06-18 the server issues a session ID in
    # response to initialize, and every later request must send it back --
    # without it the server can't tell which protocol revision the request
    # uses and rejects it. 2026-07-28 requests are self-describing (_meta plus
    # per-message headers), so they carry no session.

    def __init__(self, url, timeout, logger):
        self.url = url
        self.timeout = timeout
        self.logger = logger
        self.session_id = None
        self.protocol_version = None

    def headers_for(self, msg):
        headers = {'Content-Type': 'application/json',
                   'Accept': 'application/json'}
        if not isinstance(msg, dict):
            return headers

        method = msg.get('method')
        params = msg.get('params')
        meta = params.get('_meta') if isinstance(params, dict) else None
        stated = meta.get(META_PROTOCOL_VERSION) if isinstance(meta, dict) else None

        if stated:
            # 2026-07-28: the headers must agree with the body.
            headers[PROTOCOL_VERSION] = str(stated)
            if method:
                headers[MCP_METHOD] = str(method)
            if method in NAMED_METHODS and isinstance(params, dict):
                name = params.get('name', params.get('uri'))
                if name:
                    headers[MCP_NAME] = encode_header_value(str(name))
        elif method != 'initialize':
            # 2025-06-18: send back the session and the negotiated version.
            if self.session_id:
                headers[SESSION_ID] = self.session_id
            if self.protocol_version:
                headers[PROTOCOL_VERSION] = self.protocol_version
        return headers

    def remember(self, msg, resp, text):
        session = resp.headers.get(SESSION_ID)
        if session:
            self.session_id = session
        if isinstance(msg, dict) and msg.get('method') == 'initialize':
            try:
                version = json.loads(text)['result']['protocolVersion']
                self.protocol_version = str(version)
            except (ValueError, KeyError, TypeError):
                pass

    def forward(self, payload):
        # Returns the line to write to stdout, or None to write nothing.
        try:
            msg = json.loads(payload)
        except ValueError:
            msg = None  # Let the server report the parse error.

        # Notifications have no "id" -- the client must never receive a
        # response for them, even if the server returns an error.
        is_notification = isinstance(msg, dict) and 'id' not in msg
        msg_id = msg.get('id') if isinstance(msg, dict) else None

        if isinstance(msg, dict) and msg.get('method') == 'initialize':
            # A new connection; forget the old one.
            self.session_id = None
            self.protocol_version = None

        try:
            resp = requests.post(self.url, data=payload.encode('utf-8'),
                                 headers=self.headers_for(msg),
                                 timeout=self.timeout)
        except requests.RequestException as e:
            self.logger.error(f"Error proxying MCP request: {e}")
            if is_notification:
                return None
            return error_response(msg_id, f"MCP bridge could not reach {self.url}: {e}")

        text = resp.content.decode('utf-8')
        self.logger.debug(f"Response: {resp.status_code} ***{text}***")
        self.remember(msg, resp, text)

        if is_notification:
            if resp.status_code >= 400:
                self.logger.error(f"Notification failed: HTTP {resp.status_code} {text}")
            return None

        # Errors carry a JSON-RPC body; pass it through whatever the status.
        if text.strip():
            if resp.status_code >= 400:
                self.logger.error(f"HTTP {resp.status_code}: {text}")
            return single_line(text)

        if resp.status_code >= 400:
            self.logger.error(f"HTTP {resp.status_code} {resp.reason} with no body")
            return error_response(msg_id, f"HTTP {resp.status_code} {resp.reason}")
        return None

    def close(self):
        # End the 2025-06-18 session, if there is one. Best effort: the client
        # has already gone.
        if not self.session_id:
            return
        try:
            requests.delete(self.url, headers={SESSION_ID: self.session_id},
                            timeout=self.timeout)
        except requests.RequestException as e:
            self.logger.debug(f"Session DELETE failed: {e}")


def main():

    parser = argparse.ArgumentParser(
        description="Model Context Protocol STDIO -> HTTP proxy for MATLAB Production Server.")
    parser.add_argument("--url", type=str, default="http://localhost:9910/mcp", help="MCP endpoint on MATLAB Production Server")
    parser.add_argument("--timeout", type=int, default=30, help="HTTP request timeout in seconds.")
    parser.add_argument("--log-level", type=str, default=logging.INFO, help="Detail of messages in log file.")
    parser.add_argument("--log-file", type=str, default=os.path.basename(__file__)+".log", help="Name of log file.")
    parser.add_argument("--log-dir", type=str, default=os.getcwd(), help="Directory for storing log files.")

    args = parser.parse_args()

    logger = logging.getLogger(__name__)
    log_file = os.path.join(args.log_dir, args.log_file)
    file_handler = logging.FileHandler(log_file)
    formatter = logging.Formatter(fmt="{asctime} - {levelname} - {message}",style="{")
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    logger.setLevel(args.log_level)

    sys.stdin.reconfigure(encoding='utf-8')
    sys.stdout.reconfigure(encoding='utf-8')

    bridge = Bridge(args.url, args.timeout, logger)

    try:
        while True:
            # Every message must be a single line. It must end with a newline.
            payload = sys.stdin.readline()
            if payload == "":
                break  # End of input: the client has closed the connection.
            logger.debug(f"Payload: ***{payload}***")
            if not payload.strip():
                continue

            out = bridge.forward(payload)
            if out:
                sys.stdout.write(out + "\n")
                sys.stdout.flush()
            else:
                logger.debug("No response sent")
    finally:
        bridge.close()


if __name__ == "__main__":
    main()
