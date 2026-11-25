classdef tRequestIdType < prodserver.mcp.test.base.MCPHandlerBase
% A request whose id is an object, array, boolean or fraction is rejected
% with -32600, HTTP 400 and an id of null, under every revision. MCP
% requires a request id to be a string or an integer (JSON-RPC allows any
% number, and null, which MCP forbids too). Such requests used to be
% processed, and their id echoed back.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        badId = struct("object", struct('a', 1), "boolean", true, ...
            "fraction", 1.5, "array", [1 2])
        goodId = struct("integer", 7, "negative", -3, "string", "abc", ...
            "emptyString", "")
        % As sent: jsondecode reads [7] and [[7]] as 7, so only the text
        % shows they are arrays.
        rawBadId = struct("oneElement", '"id":[7]', "nested", '"id":[[7]]', ...
            "spaced", '"id" : [ 7 ]', "escapedKey", '"\u0069d":[7]')
        rawGoodId = struct("integer", '"id":7', ...
            "arrayInAString", '"id":"[7]"', ...
            "arrayElsewhere", '"x":{"id":[7]},"id":7')
    end

    methods (Test)

        function badIdIsInvalidRequest(test, badId)
            [response, decoded] = test.post(badId);
            test.verifyEqual(response.HttpCode, 400);
            test.assertTrue(isfield(decoded, 'error'), "An error response.");
            test.verifyEqual(decoded.error.code, -32600);
            test.verifySubstring(string(decoded.error.message), ...
                "must be a string or an integer");
            test.verifyEmpty(decoded.id, "The id is null, not echoed.");
        end

        function oneElementArrayIdIsInvalidRequest(test, rawBadId)
            [response, decoded] = test.postText(rawBadId);
            test.verifyEqual(response.HttpCode, 400);
            test.assertTrue(isfield(decoded, 'error'), "An error response.");
            test.verifyEqual(decoded.error.code, -32600);
            test.verifySubstring(string(decoded.error.message), ...
                "must be a string or an integer");
            test.verifyEmpty(decoded.id, "The id is null, not echoed.");
        end

        function arrayTextElsewhereIsNotAnArrayId(test, rawGoodId)
            [~, decoded] = test.postText(rawGoodId);
            if isfield(decoded, 'error')
                test.verifyFalse(contains(string(decoded.error.message), ...
                    "id"), string(decoded.error.message));
            end
            test.verifyNotEmpty(decoded.id);
        end

        function goodIdIsNotRejectedForIt(test, goodId)
            % Whatever else the server says of this request, it isn't
            % about the id, and the id comes back as sent.
            [~, decoded] = test.post(goodId);
            if isfield(decoded, 'error')
                test.verifyFalse(contains(string(decoded.error.message), ...
                    "id"), string(decoded.error.message));
            end
            test.verifyEqual(string(decoded.id), string(goodId));
        end

    end

    methods (Access = private)

        function [response, decoded] = postText(test, members)
        % POST a ping whose members, besides jsonrpc and method, are the
        % JSON text MEMBERS.
            body = ['{"jsonrpc":"2.0",' members ',"method":"ping"}'];
            [response, decoded] = test.postBody(body);
        end

        function [response, decoded] = post(test, id)
            body = jsonencode(struct('jsonrpc', "2.0", 'id', id, ...
                'method', "ping"));
            [response, decoded] = test.postBody(body);
        end

        function [response, decoded] = postBody(test, body)
            import prodserver.mcp.MCPConstants
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                char(prodserver.mcp.internal.Constants.MIMETypeJSON)}];
            [req, body] = test.applyProtocol(req, body);
            req.Method = "POST";
            req.Path = "/AnExcellentServer/mcp";
            req.Body = unicode2native(body, "UTF-8");
            req.Headers = [req.Headers; {MCPConstants.ContentLength, numel(req.Body)}];
            response = test.handle(req);
            decoded = prodserver.mcp.internal.decodeBody(response);
        end

    end

end
