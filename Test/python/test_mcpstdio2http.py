# test_mcpstdio2http.py
#
# Tests of the STDIO bridge, Utilities/mcpstdio2http.py. The bridge talks to
# the server with the requests package; here a fake requests module answers
# instead, from a script, so the tests need only the standard library and no
# server. Run from MATLAB by Test/integration/client/tStdioBridge.m, or:
#
#   python -B -m unittest discover -s Test/python -p "test_*.py"

# Copyright 2026 The MathWorks, Inc.

import importlib.util
import json
import logging
import os
import sys
import types
import unittest

sys.dont_write_bytecode = True  # No __pycache__ beside the bridge.

SESSION_ID = 'Mcp-Session-Id'


class FakeResponse:
    def __init__(self, status, body=None, session=None):
        self.status_code = status
        self.reason = {200: 'OK', 202: 'Accepted', 404: 'Not Found',
                       500: 'Internal Server Error'}.get(status, '')
        self.content = json.dumps(body).encode('utf-8') if body is not None else b''
        self.headers = {SESSION_ID: session} if session else {}


class FakeRequests(types.ModuleType):
    # Stands in for the requests package. Each post is answered by the next
    # function in `script`, called with the decoded message and the headers.
    class RequestException(Exception):
        pass

    def __init__(self):
        super().__init__('requests')
        self.script = []
        self.calls = []

    def post(self, url, data=None, headers=None, timeout=None):
        msg = json.loads(data.decode('utf-8'))
        self.calls.append((msg, dict(headers or {})))
        return self.script.pop(0)(msg, headers or {})

    def delete(self, url, headers=None, timeout=None):
        return FakeResponse(204)


def load_bridge(fake):
    # Import the bridge with the fake in place of requests.
    sys.modules['requests'] = fake
    path = os.path.join(os.path.dirname(__file__), '..', '..', 'Utilities',
                        'mcpstdio2http.py')
    spec = importlib.util.spec_from_file_location('mcpstdio2http', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def result(msg_id, value):
    return {'jsonrpc': '2.0', 'id': msg_id, 'result': value}


def session_not_found(msg_id):
    return {'jsonrpc': '2.0', 'id': msg_id,
            'error': {'code': -32001, 'message': 'Session not found.'}}


INITIALIZE = json.dumps({'jsonrpc': '2.0', 'id': 1, 'method': 'initialize',
                         'params': {'protocolVersion': '2025-06-18',
                                    'capabilities': {},
                                    'clientInfo': {'name': 't', 'version': '1'}}})
INITIALIZED = json.dumps({'jsonrpc': '2.0', 'method': 'notifications/initialized'})
LIST = json.dumps({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list', 'params': {}})


class TestStdioBridge(unittest.TestCase):

    def setUp(self):
        self.fake = FakeRequests()
        self.module = load_bridge(self.fake)
        logger = logging.getLogger('test_mcpstdio2http')
        logger.addHandler(logging.NullHandler())
        logger.propagate = False
        self.bridge = self.module.Bridge('http://server/mcp', 5, logger)

    def initialize_session(self, session):
        # The client's initialize and notifications/initialized, answered
        # with SESSION.
        self.fake.script += [
            lambda m, h: FakeResponse(200, result(m['id'], {
                'protocolVersion': '2025-06-18'}), session),
            lambda m, h: FakeResponse(202),
        ]
        self.bridge.forward(INITIALIZE)
        self.bridge.forward(INITIALIZED)

    def test_starts_a_new_session_on_404(self):
        # A 404 to a request with a session: the bridge replays initialize
        # and notifications/initialized, then retries the request once with
        # the new session, and returns the retry's answer.
        self.initialize_session('v1.old')
        self.fake.script += [
            lambda m, h: FakeResponse(404, session_not_found(m['id'])),
            lambda m, h: FakeResponse(200, result(m['id'], {
                'protocolVersion': '2025-06-18'}), 'v1.new'),
            lambda m, h: FakeResponse(202),
            lambda m, h: FakeResponse(200, result(m['id'], {'tools': []})),
        ]
        out = json.loads(self.bridge.forward(LIST))

        self.assertEqual(out, result(2, {'tools': []}))
        sent = [(m.get('method'), h.get(SESSION_ID)) for m, h in self.fake.calls[2:]]
        self.assertEqual(sent, [('tools/list', 'v1.old'),
                                ('initialize', None),
                                ('notifications/initialized', 'v1.new'),
                                ('tools/list', 'v1.new')])
        self.assertEqual(self.bridge.session_id, 'v1.new')

    def test_second_404_is_returned(self):
        # If the retry also gets 404, its answer goes to the client, with no
        # further attempts.
        self.initialize_session('v1.old')
        self.fake.script += [
            lambda m, h: FakeResponse(404, session_not_found(m['id'])),
            lambda m, h: FakeResponse(200, result(m['id'], {}), 'v1.new'),
            lambda m, h: FakeResponse(202),
            lambda m, h: FakeResponse(404, session_not_found(m['id'])),
        ]
        out = json.loads(self.bridge.forward(LIST))

        self.assertEqual(out['error']['code'], -32001)
        self.assertEqual(len(self.fake.calls), 6)
        self.assertEqual(self.fake.script, [])

    def test_failed_restart_returns_the_404(self):
        # If the server won't start a new session, the original 404 goes to
        # the client.
        self.initialize_session('v1.old')
        self.fake.script += [
            lambda m, h: FakeResponse(404, session_not_found(m['id'])),
            lambda m, h: FakeResponse(500, {'jsonrpc': '2.0', 'id': 1,
                                            'error': {'code': -32603,
                                                      'message': 'x'}}),
        ]
        out = json.loads(self.bridge.forward(LIST))

        self.assertEqual(out['error']['code'], -32001)
        self.assertEqual(len(self.fake.calls), 4)

    def test_no_restart_without_a_session(self):
        # A 404 to a request that carried no session ID isn't about a
        # session: Production Server answers 404 while an archive is still
        # being deployed, for example. It's passed on.
        self.fake.script += [
            lambda m, h: FakeResponse(404, session_not_found(m['id'])),
        ]
        out = json.loads(self.bridge.forward(LIST))

        self.assertEqual(out['error']['code'], -32001)
        self.assertEqual(len(self.fake.calls), 1)

    def test_no_restart_before_initialize(self):
        # Without an initialize to replay, there's nothing to restart with.
        self.bridge.session_id = 'v1.stale'
        self.fake.script += [
            lambda m, h: FakeResponse(404, session_not_found(m['id'])),
        ]
        self.bridge.forward(LIST)
        self.assertEqual(len(self.fake.calls), 1)

    def test_session_id_sent_back_unchanged(self):
        # A token is passed through exactly, URL-safe Base64 and all.
        token = 'v1.eyJzaWQiOiJhLWIiLCJjYXBzIjp7fX0-_x'
        self.initialize_session(token)
        self.fake.script += [
            lambda m, h: FakeResponse(200, result(m['id'], {'tools': []})),
        ]
        self.bridge.forward(LIST)
        self.assertEqual(self.fake.calls[-1][1].get(SESSION_ID), token)


if __name__ == '__main__':
    unittest.main()
