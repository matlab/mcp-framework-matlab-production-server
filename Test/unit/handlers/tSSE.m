classdef tSSE < prodserver.mcp.test.base.MCPHandlerBase
% Server-Sent Events are not supported, and every way of asking for them has a
% correct refusal.
%
% There are three distinct ways a client can ask for SSE, and they are not
% interchangeable -- answering one of them with another's status misleads the
% client about what the server is:
%
%   1. The deprecated HTTP+SSE transport's own endpoint, /sse. That resource
%      does not exist here, so it is 404 Not Found. 404 rather than 405 because
%      an absent resource has no honest list of methods to put in an Allow
%      header; MCP's backwards-compatibility rules name 404 and 405
%      interchangeably as the signal that the deprecated transport is
%      unavailable, so no client loses the ability to detect it.
%
%   2. GET on the Streamable HTTP endpoint, which is how a client opens a
%      server-to-client stream. That endpoint DOES exist, it just does not open
%      streams, so this is 405 Method Not Allowed with an Allow header -- the
%      status the spec explicitly mandates. Answering it with 404 would say the
%      MCP endpoint itself is absent, which would be a lie.
%
%   3. A POST whose Accept header admits an event stream and nothing else.
%      There is no representation to send such a client, so it is 406 Not
%      Acceptable. Sending it JSON it said it would not take, or an empty 200,
%      are both worse answers.
%
% The spec asks clients to list BOTH application/json and text/event-stream on a
% POST, leaving the server free to pick. Those clients must be served normally,
% which is the asymmetry the Accept tests below pin down: naming
% text/event-stream is not itself a refusable request. Only naming it to the
% exclusion of JSON is.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        % Every shape the legacy endpoint turns up in: bare, under an archive
        % name, and miscased, since paths arrive from the wire as sent.
        ssePath = {'/sse', '/prime/sse', '/AnExcellentServer/sse', '/prime/SSE'};

        % Every verb a client might try it with, including the GET the
        % deprecated transport actually used.
        sseVerb = {'GET', 'POST', 'DELETE', 'HEAD', 'OPTIONS'};

        % Accept values that leave the server a way to answer in JSON. The
        % second is what the spec asks clients to send.
        acceptableAccept = { ...
            'application/json', ...
            'application/json, text/event-stream', ...
            'text/event-stream, application/json;q=0.9', ...
            '*/*', ...
            'application/*'};

        % Accept values that admit an event stream and nothing else.
        streamOnlyAccept = { ...
            'text/event-stream', ...
            'text/event-stream;q=1.0', ...
            ' text/event-stream ', ...
            'TEXT/EVENT-STREAM'};
    end

    methods

        function response = ping(test, opts)
        %ping A request that needs no tool definitions, so these tests exercise
        %   the transport gates and nothing else.
            arguments
                test
                opts.accept (1,1) string = "omit"
                opts.path (1,1) string = "/prime/mcp"
            end

            body = '{ "jsonrpc": "2.0", "id": 1, "method": "ping" }';
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body, ...
                    accept=opts.accept, path=opts.path));
        end
    end

    methods (Test)

        function tSsePathIsNotFound(test, ssePath, sseVerb)
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest(sseVerb, "", path=ssePath));

            test.verifyEqual(response.HttpCode, 404, ...
                sprintf("%s %s must be 404", sseVerb, ssePath));
            test.verifyEmpty(response.Body, ...
                "A 404 refusal carries no body");
            test.verifyConformantResponse(response);
        end

        function tSsePathRefusalPrecedesVerbGate(test, ssePath)
        % GET is an unsupported verb AND /sse is an absent resource. The path
        % answer is the more specific and more useful one: "that endpoint is not
        % here" beats "wrong method on an endpoint that is", which would imply
        % some other verb on /sse would have worked.
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("GET", "", path=ssePath));
            test.verifyEqual(response.HttpCode, 404);
        end

        function tSsePathRefusalPrecedesOtherGates(test)
        % No session, an unsupported protocol version and an unparseable body
        % are each a refusal in their own right. None of them may displace the
        % 404: a client probing for the legacy endpoint has not negotiated
        % anything yet and must not be told its session or version is the
        % problem.
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", "{ not json", path="/prime/sse", ...
                    session="omit", protocolVersion="2024-11-05"));
            test.verifyEqual(response.HttpCode, 404);
            test.verifyEmpty(response.Body);
        end

        function tSsePathRefusalHeadersAreChar(test)
        % MATLAB Production Server requires char in the header cell array. A
        % string value is accepted here and then fails when the response is
        % serialized, far from the cause.
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("GET", "", path="/prime/sse"));
            for k = 1:size(response.Headers,1)
                test.verifyClass(response.Headers{k,1}, "char", ...
                    sprintf("Header name in row %d must be char", k));
                test.verifyClass(response.Headers{k,2}, "char", ...
                    sprintf("Header value in row %d must be char", k));
            end
        end

        function tMcpEndpointGetIsMethodNotAllowed(test)
        % The spec's own no-stream signal. This endpoint exists; it just opens
        % no server-to-client stream. 404 here would say the MCP endpoint is
        % absent and would send a client looking for a different URL.
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("GET"));

            test.verifyEqual(response.HttpCode, 405);
            test.verifyNotEqual(response.HttpCode, 404);
            allow = prodserver.mcp.internal.getHeaderValue( ...
                'Allow', response.Headers);
            test.assertNotEmpty(allow, "A 405 must carry an Allow header");
            test.verifyFalse(contains(string(allow),"GET"), ...
                "Allow must not list the verb that was just refused");
            test.verifyConformantResponse(response);
        end

        function tStreamOnlyAcceptIsNotAcceptable(test, streamOnlyAccept)
            response = test.ping(accept=streamOnlyAccept);

            test.verifyEqual(response.HttpCode, 406, ...
                sprintf("Accept: %s leaves nothing to send", streamOnlyAccept));
            test.verifyEmpty(response.Body, ...
                "A 406 refusal carries no body");
            test.verifyConformantResponse(response);
        end

        function tAcceptAdmittingJsonIsServed(test, acceptableAccept)
        % The case that matters most: a spec-conformant client lists
        % text/event-stream alongside application/json, and must be served
        % normally rather than refused for mentioning SSE at all.
            response = test.ping(accept=acceptableAccept);

            test.verifyEqual(response.HttpCode, 200, ...
                sprintf("Accept: %s admits JSON and must be served", ...
                    acceptableAccept));
            test.verifyConformantResponse(response);
        end

        function tAbsentAcceptIsServed(test)
        % An absent Accept means */*. This framework's own client sends no
        % Accept header, so refusing here would break it against itself.
            response = test.ping();
            test.verifyEqual(response.HttpCode, 200);
            test.verifyConformantResponse(response);
        end

        function tAcceptGateDoesNotApplyToDelete(test)
        % Content negotiation is about the representation of a response body. A
        % session-termination DELETE has no body either way, so there is nothing
        % to negotiate and nothing to refuse.
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("DELETE", "", accept="text/event-stream"));

            test.verifyEqual(response.HttpCode, 204);
            test.verifyConformantResponse(response);
        end

        function tNotAcceptableRefusalCarriesNoJsonRpcBody(test)
        % 406 is a transport-level refusal: the request never reached the
        % JSON-RPC layer, so there is no JSON-RPC error to report -- and
        % reporting one would mean sending a body in the very format the client
        % said it would not accept.
            response = test.ping(accept="text/event-stream");
            test.verifyEmpty(response.Body);
            test.verifyEmpty(prodserver.mcp.internal.getHeaderValue( ...
                prodserver.mcp.MCPConstants.ContentType, response.Headers));
        end

        function tAcceptGateRunsBeforeDecoding(test)
        % A body that could never be parsed must still be refused with 406, not
        % answered with a 200 and a -32700: there is no way to deliver that
        % -32700 to a client that will not read JSON.
            body = "{ not json";
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body, accept="text/event-stream"));
            test.verifyEqual(response.HttpCode, 406);
            test.verifyEmpty(response.Body);
        end

    end
end
