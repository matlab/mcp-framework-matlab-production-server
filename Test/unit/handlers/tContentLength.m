classdef tContentLength < prodserver.mcp.test.base.MCPHandlerBase
% Every bodiless response carries no body, no Content-Type, and no
% Content-Length -- because MPS supplies the framing itself.
%
% A response with no body is not the same thing as a response that has not
% finished arriving, and a client can only tell the two apart if the length is
% stated. It is: measured against a live R2026b instance, MPS emits
% Content-Length on every response it sends from a custom web handler, and
% Content-Length: 0 when the body is empty. Nothing is lost by staying quiet.
%
% This file originally demanded the opposite -- that the handler state
% Content-Length: 0 itself. On the wire that produced the header TWICE on every
% bodiless response, MPS's copy plus the handler's, which no unit test could
% catch because the duplication happens downstream of the struct a unit test
% sees. Only a live HTTP probe showed it. A duplicate header is how a client
% ends up honouring a value the server did not mean, so the handler now leaves
% framing alone and this file pins that.
%
% Bodied responses were never given a Content-Length, for the same reason that
% now applies to bodiless ones: MPS computes it from the body it serializes, and
% a second opinion could only ever agree or contradict -- a wrong length being
% worse than an absent one, since the client truncates or waits on it.

% Copyright 2026 The MathWorks, Inc.

    methods

        function verifyDeclaresEmpty(test, response, expectedCode)
        %verifyDeclaresEmpty Assert a response is the empty one it claims to be.
            import prodserver.mcp.MCPConstants

            test.verifyEqual(response.HttpCode, expectedCode);
            test.assertEmpty(response.Body, sprintf( ...
                "HTTP %d is expected to carry no body", expectedCode));

            % MPS frames the empty body as Content-Length: 0 on its own, so a
            % length stated here is a second copy of the header on the wire.
            len = prodserver.mcp.internal.getHeaderValue( ...
                MCPConstants.ContentLength, response.Headers);
            test.verifyEmpty(len, sprintf( ...
                "HTTP %d must leave Content-Length to MPS, but set it to '%s'", ...
                expectedCode, string(len)));

            % Content-Type describes a body. There is none to describe.
            test.verifyEmpty(prodserver.mcp.internal.getHeaderValue( ...
                MCPConstants.ContentType, response.Headers), sprintf( ...
                "HTTP %d must not advertise a Content-Type", expectedCode));

            test.verifyConformantResponse(response);
        end
    end

    methods (Test)

        function tSsePathNotFound(test)
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", "", path="/prime/sse"));
            test.verifyDeclaresEmpty(response, 404);
        end

        function tUnsupportedVerb(test)
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("GET"));
            test.verifyDeclaresEmpty(response, 405);
        end

        function tNotAcceptable(test)
            body = '{ "jsonrpc": "2.0", "id": 1, "method": "ping" }';
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body, accept="text/event-stream"));
            test.verifyDeclaresEmpty(response, 406);
        end

        function tUnsupportedProtocolVersion(test)
            body = '{ "jsonrpc": "2.0", "id": 1, "method": "ping" }';
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body, protocolVersion="2025-03-26"));
            test.verifyDeclaresEmpty(response, 400);
        end

        function tMissingSession(test)
            body = '{ "jsonrpc": "2.0", "id": 1, "method": "ping" }';
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body, session="omit"));
            test.verifyDeclaresEmpty(response, 400);
        end

        function tDeleteWithoutSession(test)
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("DELETE", "", session="omit"));
            test.verifyDeclaresEmpty(response, 400);
        end

        function tSessionTerminated(test)
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("DELETE"));
            test.verifyDeclaresEmpty(response, 204);
        end

        function tNotificationAccepted(test)
        % A notification has no id, so there is no reply to carry -- but the
        % acknowledgement still has to say that out loud. This one comes through
        % the main response assembly rather than the early-refusal path, so it
        % is the case that would break if the two diverged.
            body = ['{ "jsonrpc": "2.0", ' ...
                    '"method": "notifications/initialized" }'];
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body));
            test.verifyDeclaresEmpty(response, 202);
        end

        function tNotificationWhoseHandlerFailed(test)
        % Still 202, still empty, still declared: an unknown notification is
        % handled by raising, and the error is then discarded because JSON-RPC
        % forbids replying to a request with no id. The discarding happens after
        % data and msgHeaders may already have been set, so this is where a
        % stale Content-Type or a leftover body would surface.
            body = ['{ "jsonrpc": "2.0", ' ...
                    '"method": "notifications/nothingLikeThisExists" }'];
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body));
            test.verifyDeclaresEmpty(response, 202);
        end

        function tBodiedResponseIsLeftToTheServer(test)
        % The other half of the contract. A response that does have a body
        % carries application/json and no handler-computed length: MPS derives
        % the length from what it serializes, and a disagreement between the two
        % is a truncated or hung read.
            body = '{ "jsonrpc": "2.0", "id": 1, "method": "ping" }';
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body));

            test.verifyEqual(response.HttpCode, 200);
            test.assertNotEmpty(response.Body);
            test.verifyEmpty(prodserver.mcp.internal.getHeaderValue( ...
                prodserver.mcp.MCPConstants.ContentLength, response.Headers), ...
                "A bodied response must not carry a handler-computed length");
            test.verifyConformantResponse(response);
        end

    end
end
