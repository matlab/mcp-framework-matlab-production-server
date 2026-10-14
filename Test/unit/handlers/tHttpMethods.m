classdef tHttpMethods < prodserver.mcp.test.base.MCPHandlerBase
% The HTTP verb gate. POST and DELETE are the only verbs this transport
% supports; everything else is 405 Method Not Allowed with an Allow header.
%
% This is the regression test for an outright crash: mcpHandler used to assign
% httpCode only inside the switch arms it knew about, so an unsupported verb
% reached the response assembly with it undefined and took the handler down.
%
% GET -> 405 is also load-bearing protocol, not just tidiness. It is how a
% client discovers this server has no SSE/Streamable HTTP stream to open, so the
% verb gate runs ahead of path parsing, metrics, and every other gate: a 400
% from the session or protocol-version check, or a 500 from failing to parse the
% archive name out of the URL, would both mislead the client about the transport.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        % HEAD and OPTIONS matter for real deployments: a browser-based client
        % sends OPTIONS as a CORS preflight, and proxies send HEAD.
        unsupportedVerb = {'GET', 'PUT', 'PATCH', 'OPTIONS', 'HEAD'};
    end

    methods (Test)

        function tUnsupportedVerbIsMethodNotAllowed(test, unsupportedVerb)
            reqT = test.rawRequest(unsupportedVerb);
            response = prodserver.mcp.internal.mcpHandler(reqT);

            test.verifyEqual(response.HttpCode, 405);
            test.verifyEmpty(response.Body, ...
                "A 405 refusal carries no body");
            test.verifyConformantResponse(response);
        end

        function tMethodNotAllowedAdvertisesAllow(test, unsupportedVerb)
        % RFC 9110 requires Allow on a 405, and a CORS preflight depends on
        % reading it.
            reqT = test.rawRequest(unsupportedVerb);
            response = prodserver.mcp.internal.mcpHandler(reqT);

            allow = prodserver.mcp.internal.getHeaderValue( ...
                'Allow', response.Headers);
            test.assertNotEmpty(allow, "A 405 must carry an Allow header");
            test.verifyTrue(contains(string(allow),"POST"));
            test.verifyTrue(contains(string(allow),"DELETE"));
        end

        function tVerbGateRunsBeforePathParsing(test, unsupportedVerb)
        % A URL the handler cannot parse an archive name out of must not turn
        % the 405 into a 500. The verb is a property of the request line and is
        % knowable without looking at the path at all.
            reqT = test.rawRequest(unsupportedVerb, "", path="/");
            response = prodserver.mcp.internal.mcpHandler(reqT);
            test.verifyEqual(response.HttpCode, 405);
        end

        function tVerbGateRunsBeforeSessionGate(test)
        % No session header: a POST here would be 400, but the verb is checked
        % first, so the client still learns there is no SSE transport.
            reqT = test.rawRequest("GET", "", session="omit");
            response = prodserver.mcp.internal.mcpHandler(reqT);
            test.verifyEqual(response.HttpCode, 405);
        end

        function tVerbGateRunsBeforeVersionGate(test)
            reqT = test.rawRequest("GET", "", protocolVersion="1999-01-01");
            response = prodserver.mcp.internal.mcpHandler(reqT);
            test.verifyEqual(response.HttpCode, 405);
        end

        function tHeadersAreChar(test)
        % MATLAB Production Server requires char, not string, in the header
        % cell array. A string value here is accepted by the handler and then
        % fails at the point the response is serialized, far from the cause.
            reqT = test.rawRequest("GET");
            response = prodserver.mcp.internal.mcpHandler(reqT);
            for k = 1:size(response.Headers,1)
                test.verifyClass(response.Headers{k,1}, "char", ...
                    sprintf("Header name in row %d must be char", k));
                test.verifyClass(response.Headers{k,2}, "char", ...
                    sprintf("Header value in row %d must be char", k));
            end
        end

    end
end
