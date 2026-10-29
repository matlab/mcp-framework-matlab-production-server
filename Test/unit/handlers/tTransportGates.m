classdef tTransportGates < matlab.unittest.TestCase
% The checks mcpHandler makes on the HTTP method and the Accept header before
% it looks at the path, the body or the protocol (conformance Phase 6: G11,
% XD3, XD19, XD22).
%
% Not built on MCPHandlerBase, for the reason tVersionResolution gives: every
% request here is hand-built, and the ones expected to get past the gates use
% `ping` and `initialize`, which need no tool definitions. Every response is
% also run through verifyConformantResponse.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Initialize = ['{"jsonrpc":"2.0","id":1,"method":"initialize",' ...
            '"params":{"protocolVersion":"2025-06-18","capabilities":{},' ...
            '"clientInfo":{"name":"t","version":"1"}}}']
    end

    methods (Access = private)

        function response = send(test, method, opts)
            arguments
                test
                method string
                opts.path char = '/prime/mcp'
                opts.body char = ''
                opts.headers cell = cell(0,2)
            end
            import prodserver.mcp.MCPConstants

            req = struct('ApiVersion', [1 0 0], 'Method', method, ...
                'Path', opts.path);
            req.Headers = opts.headers;
            if ~isempty(opts.body)
                req.Headers = [req.Headers; ...
                    {MCPConstants.ContentType, 'application/json'}];
                req.Body = unicode2native(opts.body, "UTF-8");
            else
                req.Body = uint8.empty(1,0);
            end
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentLength, char(string(numel(req.Body)))}];

            response = prodserver.mcp.internal.mcpHandler(req);
            prodserver.mcp.test.verifyConformantResponse(test, response);
        end

        function verify405(test, response, allow)
            test.verifyEqual(response.HttpCode, 405);
            test.verifyEqual(prodserver.mcp.internal.getHeaderValue( ...
                'Allow', response.Headers), allow, ...
                "RFC 9110 §15.5.6: a 405 MUST carry Allow");
            test.verifyEmpty(response.Body);
        end

        function response = postAccepting(test, accept)
            response = test.send("POST", body=test.Initialize, ...
                headers={'Accept', accept});
        end

    end

    methods (Test)

        % G11 and XD3: every 405 says what is allowed, wherever it fires.

        function getIs405WithAllow(test)
            test.verify405(test.send("GET"), 'POST, DELETE');
        end

        function getWithoutServerSegmentIs405(test)
            % Used to be a 500: the path check ran before the verb check.
            test.verify405(test.send("GET", path='/mcp'), 'POST, DELETE');
        end

        function otherVerbsAre405WithAllow(test)
            for m = ["PUT", "PATCH", "OPTIONS", "HEAD"]
                test.verify405(test.send(m), 'POST, DELETE');
            end
        end

        function unattributableDeleteIs405WithAllow(test)
            test.verify405(test.send("DELETE"), 'POST, DELETE');
        end

        function v20260728DeleteIs405AllowingPost(test)
            % The adapter knows its revision has no sessions, so it can say
            % more than the endpoint-wide default.
            [~, code, ~, headers] = ...
                prodserver.mcp.protocol.v20260728.Adapter().handleDelete([]);
            test.verifyEqual(code, 405);
            test.verifyEqual(prodserver.mcp.internal.getHeaderValue( ...
                'Allow', headers), 'POST');
        end

        % XD19: one Server header, everywhere.

        function serverHeaderIsTheConstant(test)
            for r = {test.send("GET"), test.send("POST", body=test.Initialize)}
                test.verifyEqual(prodserver.mcp.internal.getHeaderValue( ...
                    'Server', r{1}.Headers), ...
                    prodserver.mcp.MCPConstants.ServerHeader);
            end
        end

        % XD22: Accept.

        function eventStreamOnlyIs406(test)
            response = test.postAccepting('text/event-stream');
            test.verifyEqual(response.HttpCode, 406);
            test.verifyEmpty(response.Body);
        end

        function unrelatedTypeIs406(test)
            test.verifyEqual(test.postAccepting('text/html').HttpCode, 406);
        end

        function jsonIsAcceptedWhateverItsParameters(test)
            for accept = ["application/json", ...
                    "application/json, text/event-stream", ...
                    "text/event-stream, application/json;q=0.9", ...
                    "Application/JSON ; charset=utf-8", ...
                    "application/*", "*/*;q=0.1"]
                response = test.postAccepting(char(accept));
                test.verifyEqual(response.HttpCode, 200, accept);
            end
        end

        function absentAcceptIsAccepted(test)
            % RFC 9110 §12.5.1: no Accept means any type is acceptable.
            test.verifyEqual(test.send("POST", body=test.Initialize).HttpCode, ...
                200);
        end

        function acceptSplitAcrossFieldsCounts(test)
            response = test.send("POST", body=test.Initialize, ...
                headers={'Accept', 'text/event-stream'; ...
                         'accept', 'application/json'});
            test.verifyEqual(response.HttpCode, 200);
        end

        function deleteIsNotGatedOnAccept(test)
            % A DELETE answer has no body, so there is nothing to be
            % unacceptable.
            response = test.send("DELETE", headers={'Accept', 'text/html'});
            test.verifyEqual(response.HttpCode, 405);
        end

    end

end
