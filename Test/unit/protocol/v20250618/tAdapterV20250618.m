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

        function tHandleDeleteReturns204(test)
            import prodserver.mcp.protocol.v20250618.Constants
            request = struct('Headers', ...
                {{Constants.SessionId, 'abc-123'}});
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
            % revision's 404.
            import prodserver.mcp.MCPConstants

            % {identifier, expected code, expected status}
            rows = {
                'prodserver:mcp:MethodNotFound',       MCPConstants.ErrorMethodNotFound, 200
                'prodserver:mcp:ResourceNotFound',     -32002,                           200
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
            request = struct('Headers', ...
                {{Constants.SessionId, 'sess-xyz'}});
            jrpc = struct();
            headers = test.adapter.responseHeaders(request, jrpc);
            test.verifyEqual(headers{1,1}, char(Constants.SessionId));
            test.verifyEqual(headers{1,2}, 'sess-xyz');
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
