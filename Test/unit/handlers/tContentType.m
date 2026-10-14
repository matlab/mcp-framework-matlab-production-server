classdef tContentType < prodserver.mcp.test.base.MCPHandlerBase
% The request Content-Type: every spelling of JSON is decoded as JSON, and
% every other type is refused with 415.
%
% Media types are case-insensitive and may carry parameters (RFC 9110 8.3.1).
% Comparing the raw header value against "application/json" left a body sent as
% "application/json; charset=utf-8" -- the default in several HTTP client
% libraries -- undecoded, and the client was told its well-formed request was a
% -32700 parse error. Those are the jsonContentType cases below.
%
% A body declared as something other than JSON was answered the same way: a
% -32700 that blamed the body's syntax when the problem was its declared type.
% It is now a transport-level 415 Unsupported Media Type, bodiless like every
% other transport refusal. That includes application/x-www-form-urlencoded,
% which is what curl -d sends unless told otherwise.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        % Every one of these names application/json.
        jsonContentType = { ...
            'application/json', ...
            'application/json; charset=utf-8', ...
            'application/json;charset=UTF-8', ...
            'Application/JSON', ...
            'APPLICATION/JSON ; charset="utf-8"', ...
            ' application/json '};

        % None of these does. application/jsonx pins that the comparison is on
        % the whole media type, not a prefix of it.
        otherContentType = { ...
            'text/plain', ...
            'application/xml', ...
            'application/octet-stream', ...
            'application/x-www-form-urlencoded', ...
            'application/jsonx'};
    end

    methods

        function response = ping(test, contentType, opts)
        %ping A request that needs no tool definitions, so these tests exercise
        %   the decoding and the transport gates and nothing else.
            arguments
                test
                contentType (1,1) string
                opts.body (1,1) string = ...
                    '{ "jsonrpc": "2.0", "id": 4, "method": "ping" }'
                opts.session (1,1) string = "auto"
            end

            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", opts.body, ...
                    contentType=contentType, session=opts.session));
        end
    end

    methods (Test)

        function tJsonContentTypeIsDecoded(test, jsonContentType)
            response = test.ping(jsonContentType);

            test.verifyConformantResponse(response);
            test.verifyEqual(response.HttpCode, 200, ...
                sprintf("Content-Type: %s is JSON and must be served", ...
                    jsonContentType));
            jrpc = test.responseBody(response);
            test.verifyFalse(isfield(jrpc,"error"), ...
                sprintf("Content-Type: %s must not be refused as not-JSON", ...
                    jsonContentType));
            test.verifyEqual(jrpc.id, 4, ...
                "The reply must answer the request that was sent");
            test.verifyTrue(isfield(jrpc,"result"));
        end

        function tAbsentContentTypeIsDecoded(test)
        % JSON is the only body this transport accepts, so an unstated type is
        % the one type there is. The rawRequest convention for "no header" is
        % an empty contentType.
            response = test.ping("");

            test.verifyConformantResponse(response);
            test.verifyEqual(response.HttpCode, 200);
            jrpc = test.responseBody(response);
            test.verifyTrue(isfield(jrpc,"result"));
        end

        function tOtherContentTypeIsUnsupported(test, otherContentType)
            response = test.ping(otherContentType);

            test.verifyEqual(response.HttpCode, 415, ...
                sprintf("Content-Type: %s is not JSON", otherContentType));
            test.verifyEmpty(response.Body, ...
                "A 415 refusal carries no body");
            test.verifyConformantResponse(response);
        end

        function tUnsupportedMediaTypePrecedesDecoding(test)
        % A body that could never be parsed, declared as a type that is not
        % JSON, is refused for its type. Reporting -32700 would blame the
        % body's syntax for what is a mislabelled request.
            response = test.ping("text/plain", body="{ not json");
            test.verifyEqual(response.HttpCode, 415);
        end

        function tUnsupportedMediaTypePrecedesSessionGate(test)
        % The type is checked before anything that needs the body decoded, and
        % the session gate needs it decoded to tell initialize apart. A client
        % that mislabels every request should hear about the label first.
            response = test.ping("text/plain", session="omit");
            test.verifyEqual(response.HttpCode, 415);
        end

        function tContentTypeGateDoesNotApplyToDelete(test)
        % A session-termination DELETE carries no JSON-RPC body, so the type
        % of the body it does not have is not the server's concern.
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("DELETE", "", contentType="text/plain"));

            test.verifyEqual(response.HttpCode, 204);
            test.verifyConformantResponse(response);
        end

        function tNotAcceptablePrecedesUnsupportedMediaType(test)
        % A request that fails both gates gets the 406. Nothing the server
        % says about the request body can be delivered to a client that will
        % not read the response.
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", "{}", contentType="text/plain", ...
                    accept="text/event-stream"));
            test.verifyEqual(response.HttpCode, 406);
        end

    end
end
