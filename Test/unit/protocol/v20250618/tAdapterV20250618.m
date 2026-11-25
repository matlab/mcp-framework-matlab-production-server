classdef tAdapterV20250618 < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.v20250618.Adapter.

% Copyright 2026 The MathWorks, Inc.

    properties (Access = private)
        adapter
    end

    methods (TestMethodSetup)
        function createAdapter(test)
            test.adapter = prodserver.mcp.protocol.v20250618.Adapter();
        end
    end

    methods (Test)

        function tMatchesInitializeMethod(test)
            request = struct('Headers', {{}});
            jrpc = struct('method', 'initialize');
            test.verifyTrue(test.adapter.matches(request, jrpc));
        end

        function tMatchesSessionHeader(test)
            import prodserver.mcp.protocol.v20250618.Constants
            request = struct('Headers', {{Constants.SessionId, 'abc-123'}});
            jrpc = struct('method', 'tools/call');
            test.verifyTrue(test.adapter.matches(request, jrpc));
        end

        function tNoMatchWithoutSignal(test)
            request = struct('Headers', {{}});
            jrpc = struct('method', 'tools/call');
            test.verifyFalse(test.adapter.matches(request, jrpc));
        end

        function tHandlePostInitialize(test)
            import prodserver.mcp.protocol.v20250618.Constants
            request = struct('Headers', {{}});
            jrpc = struct('jsonrpc', '2.0', 'id', 1, ...
                'method', 'initialize', ...
                'params', struct('protocolVersion', '2025-06-18'));
            [result, httpCode, ~, msgHeaders] = ...
                test.adapter.handlePost(request, jrpc);
            test.verifyEqual(httpCode, 200);
            test.verifyEqual(result.id, 1);
            test.verifyTrue(isfield(result.result, 'protocolVersion'));
            test.verifyEqual(msgHeaders{1,1}, char(Constants.SessionId));
        end

        function tHandlePostPing(test)
            request = struct('Headers', {{}});
            jrpc = struct('jsonrpc', '2.0', 'id', 42, 'method', 'ping');
            [result, httpCode, ~, ~] = test.adapter.handlePost(request, jrpc);
            test.verifyEqual(httpCode, 200);
            test.verifyEqual(result.id, 42);
            test.verifyEmpty(fieldnames(result.result));
        end

        % There are deliberately no notification tests here. Notifications
        % never reach any adapter's handlePost: mcpHandler acknowledges them
        % at stage B, ahead of detection. Asserting a 202 off a direct
        % handlePost call would pin an unreachable branch alive and read as
        % though notification routing were per-protocol, which it is not.
        % tmcpHandler covers the real path end to end -- initialized,
        % cancelled, cancelled-with-params, and an unknown notifications/*
        % method -- and tInitialized and tCancelled cover the handlers.

        function tContextFromSessionToken(test)
        % The client's capabilities come back from the session ID that
        % initialize issued. This revision carries no client info per request.
            import prodserver.mcp.protocol.v20250618.Constants
            token = prodserver.mcp.test.sessionToken(jsondecode( ...
                '{"extensions":{"io.modelcontextprotocol/ui":{}}}'));
            request = struct('Headers', {{Constants.SessionId, token}});
            jrpc = struct('jsonrpc', '2.0', 'id', 1, 'method', 'tools/list');
            ctx = test.adapter.requestContext(request, jrpc);
            test.verifyEqual(ctx.Version, Constants.Version);
            test.verifyTrue(supports(ctx.Capabilities, "io.modelcontextprotocol/ui"));
            test.verifyEqual(ctx.ClientInfo, []);
        end

        function tContextWithoutExtension(test)
            import prodserver.mcp.protocol.v20250618.Constants
            request = struct('Headers', ...
                {{Constants.SessionId, prodserver.mcp.test.sessionToken()}});
            jrpc = struct('jsonrpc', '2.0', 'id', 1, 'method', 'tools/list');
            ctx = test.adapter.requestContext(request, jrpc);
            test.verifyFalse(supports(ctx.Capabilities, "io.modelcontextprotocol/ui"));
        end

        function tUnknownSessionRefused(test)
        % A session ID this server didn't issue is refused before anything
        % runs, for every request but initialize, and for DELETE.
            import prodserver.mcp.protocol.v20250618.Constants
            unknown = {'abc-123', char(matlab.lang.internal.uuid), ...
                ['v1.' repmat('A', 1, 2000)]};
            for n = 1:numel(unknown)
                request = struct('Headers', {{Constants.SessionId, unknown{n}}});
                jrpc = struct('jsonrpc', '2.0', 'id', 1, 'method', 'tools/list');
                test.verifyError(@() test.adapter.handlePost(request, jrpc), ...
                    "prodserver:mcp:SessionNotFound", unknown{n});
                test.verifyError(@() test.adapter.handleDelete(request), ...
                    "prodserver:mcp:SessionNotFound", unknown{n});
            end
        end

        function tHandleDeleteReturns204(test)
            import prodserver.mcp.protocol.v20250618.Constants
            request = struct('Headers', ...
                {{Constants.SessionId, prodserver.mcp.test.sessionToken()}});
            [result, httpCode, httpMsg, msgHeaders] = ...
                test.adapter.handleDelete(request);
            test.verifyEqual(httpCode, 204);
            test.verifyEqual(httpMsg, 'No Content');
            test.verifyEmpty(result);
            % The session id is echoed via responseHeaders, not here, so
            % that mcpHandler does not emit a duplicate Mcp-Session-Id.
            test.verifyEmpty(msgHeaders);
        end

        function tErrorTableCodeAndStatus(test)
            % The rows of v20250618.mapErrorCode that are specific to THIS
            % revision, asserting the code AND the status together. Under
            % Streamable HTTP a JSON-RPC error is normally carried in the body
            % over HTTP 200 -- the transport succeeded -- so only a genuine
            % internal error is a 500.
            %
            % The rows every revision agrees on are not repeated here; they
            % are in tAdapterErrorMapping, parameterized by version, because
            % as byte-identical copies in two suites they were an invitation
            % to update one and not the other. What is left is exactly the
            % disagreement: -32002 is this revision's dedicated
            % resource-not-found code, which 2026-07-28 MUST NOT emit, and
            % MethodNotFound's 200 is its mandated status against that
            % revision's 404. SessionNotFound is this revision's alone: only
            % it has sessions, and its 404 tells the client to start a new one.
            import prodserver.mcp.MCPConstants

            % {identifier, expected code, expected status}
            rows = {
                'prodserver:mcp:MethodNotFound',       MCPConstants.ErrorMethodNotFound, 200
                'prodserver:mcp:ResourceNotFound',     -32002,                           200
                'prodserver:mcp:SessionNotFound',      -32001,                           404
                };

            jrpc = struct('jsonrpc', '2.0', 'id', 1, 'method', 'test');
            for k = 1:size(rows,1)
                ident = rows{k,1};
                try
                    error(ident, 'synthetic');
                catch me
                    [result, httpCode] = test.adapter.formatError(me, jrpc);
                end
                test.verifyEqual(result.error.code, rows{k,2}, ...
                    "code for " + ident);
                test.verifyEqual(httpCode, rows{k,3}, ...
                    "status for " + ident);
            end
        end

        % Six former tests stood here, each raising one identifier and
        % restating a single row of the table above: MethodNotFound over 200,
        % ResourceNotFound as -32002, an unmapped identifier as -32603 and as
        % 500 (two separate tests for the one row), the null-id echo, and the
        % per-era status contrast. They are gone rather than moved: the two
        % rows that are this revision's own are asserted once, above, and the
        % revision-independent ones are in tAdapterErrorMapping where every
        % registered revision is held to them. The status contrast moved there
        % too, as tMethodNotFoundCodeIsSharedButStatusIsNot -- it was never a
        % fact about this adapter, it reached into the other one to make its
        % point.

        function tResponseHeadersPropagatesSession(test)
            import prodserver.mcp.protocol.v20250618.Constants
            token = prodserver.mcp.test.sessionToken();
            request = struct('Headers', {{Constants.SessionId, token}});
            jrpc = struct();
            headers = test.adapter.responseHeaders(request, jrpc);
            test.verifyEqual(headers{1,1}, char(Constants.SessionId));
            test.verifyEqual(headers{1,2}, token);
        end

        function tResponseHeadersDontEchoUnknownSession(test)
        % A session ID this server didn't issue isn't echoed, including on
        % the 404 that refuses it: an echoed client value could make the
        % response headers arbitrarily long.
            import prodserver.mcp.protocol.v20250618.Constants
            for unknown = {'sess-xyz', ['v1.' repmat('A', 1, 5000)]}
                request = struct('Headers', {{Constants.SessionId, unknown{1}}});
                % No version header either, so nothing at all to send.
                headers = test.adapter.responseHeaders(request, struct());
                test.verifyEmpty(headers, "Echoed " + extractBefore( ...
                    string(unknown{1}) + blanks(20), 20));
            end
        end

        function tResponseHeadersEmptyWithoutSession(test)
            request = struct('Headers', {{}});
            jrpc = struct();
            headers = test.adapter.responseHeaders(request, jrpc);
            test.verifyEmpty(headers);
        end

        function tResponseHeadersEchoTheVersionRoutedOn(test)
            % The echo is read the way routing reads it (headerVersion), so
            % padding the client sent does not come back: routing saw
            % "2025-06-18", and that is the version the response states.
            request = struct('Headers', {{ ...
                prodserver.mcp.MCPConstants.ProtocolVersion, ' 2025-06-18 '}});
            headers = test.adapter.responseHeaders(request, struct());
            test.verifyEqual(headers, {'MCP-Protocol-Version', '2025-06-18'});
        end

    end

end
