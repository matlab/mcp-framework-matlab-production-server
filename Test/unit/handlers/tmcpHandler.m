classdef tmcpHandler < prodserver.mcp.test.base.MCPHandlerBase
% Wide selection of tests for the mcpHandler function. 

% Copyright 2026 The MathWorks, Inc.

    properties (ClassSetupParameter)
        encoding = { prodserver.mcp.WireEncoding.JSON, ...
            prodserver.mcp.WireEncoding.Invertible };
    end

    methods (TestClassSetup)

        function prepareTools(test,encoding)
            import matlab.unittest.fixtures.PathFixture

            % Add examples to the path
            test.applyFixture(prodserver.mcp.test.mixin.RequireExamples());

            % Add server tools to the path
            test.applyFixture(PathFixture(...
                fullfile(prodserver.mcp.internal.packageFolder(), ...
                         "server","tools")));

            % Assume defineForMCP is working. It has its own tests. :-)
            % Better decoupling requires a lot of (probably unnecessary)
            % work.
            test.fcnNames = ["plotTrajectoriesMCP","primeSequence",...
                "read_mcp_resource"];
            test.toolNames = ["plotTrajectories","primeSequence", ...
                "read_mcp_resource"];

            defineTools(test,test.fcnNames,test.toolNames,encoding=encoding);
        end
    end

    methods
        function validateWireEncoding(test, result, contentsExists)
            import prodserver.mcp.MCPConstants

            if contentsExists == false
                test.verifyTrue(isfield(result,"uri"),"uri missing");
                test.verifyTrue(isfield(result,"name"),"name missing");
                test.verifyTrue(isfield(result,"description"),"description missing");
                test.verifyTrue(isfield(result,"mimeType"),"mimeType missing");
                test.verifyTrue(isfield(result,"title"),"title missing");

                % Known field values
                test.verifyEqual(string(result.name), MCPConstants.WireEncodingResource.name);
                test.verifyEqual(string(result.uri), MCPConstants.WireEncodingResource.uri);
                test.verifyEqual(string(result.title), MCPConstants.WireEncodingResource.title);
                test.verifyEqual(string(result.mimeType), MCPConstants.WireEncodingResource.mimeType);
                test.verifyEqual(string(result.description), MCPConstants.WireEncodingResource.description);
            else
                % Contents equal to the text in the file
                test.verifyEqual(isfield(result,"contents"),contentsExists,...
                    "contents existence test");
                test.verifyEqual(string(result.contents.uri),...
                    MCPConstants.WireEncodingResource.uri);
                test.verifyEqual(string(result.contents.mimeType), ...
                    MCPConstants.WireEncodingResource.mimeType);

                % Make sure the definition file is where we expect it to
                % be.
                w = string(which(MCPConstants.DefinitionFile));
                test.assertEqual(w,test.definitionFile);

                if exist(MCPConstants.WireEncodingResource.contents,"file") == 2
                    actual = strtrim(split(string(result.contents.text),newline));
                    txt = readlines(MCPConstants.WireEncodingResource.contents);
                    expected = strtrim(split(strjoin(txt,newline),newline));

                    % Test each line for equality and report first unequal
                    % line.
                    for n = 1:numel(expected)
                        if n <= numel(actual)
                            test.assertEqual(actual(n),expected(n),"Line " + string(n));
                        end
                    end
                else
                    test.verifyEqual(string(result.contents.text), ...
                        MCPConstants.WireEncodingResource.contents);
                end
            end
        end
    end

    methods(Test)

        % DELETE is not tested here. Both cases -- the bare DELETE that no
        % revision can attribute (405) and the session-naming DELETE that is
        % acknowledged with 204 and echoes the id exactly once -- live in
        % tVersionResolution, which is not parameterized by protocol. They
        % belong there: DELETE routing is decided entirely by whether a
        % revision claims the request, so running the bare case once per
        % protocol parameter re-ran an identical test, and the session case
        % had to filter every parameter but one away.

        function resourcesRead(test)
            import prodserver.mcp.internal.hasField
            import prodserver.mcp.MCPConstants

            % Get base request structure
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];

            % Get the resource
            uri = char(MCPConstants.WireEncodingResourceURI);
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "resources/read",' ...
                '"params": { "uri": "' uri '"}}'];
            [req, body] = test.applyProtocol(req, body);

            reqT = req;
            reqT.Method = "POST";  % Because there's a body
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = test.handle(reqT);
            response = prodserver.mcp.internal.decodeBody(response);

            test.verifyEqual(response.id, 1);   
            if isfield(response.result,"isError")
                test.verifyEqual(response.result.isError,false,"isError true");
            end
            test.verifyTrue(hasField(response,'result.contents'));
            test.verifyEqual(numel(response.result.contents),1,"Number of contents");

            validateWireEncoding(test,response.result,true);
        end

        function resourcesList(test)
            import prodserver.mcp.internal.hasField
            import prodserver.mcp.MCPConstants

            % Get base request structure
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];

            % List all resources
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "resources/list",' ...
                '"params": { "cursor": "optional-cursor-value"}}'];
            [req, body] = test.applyProtocol(req, body);

            reqT = req;
            reqT.Method = "POST";  % Because there's a body
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = test.handle(reqT);
            response = prodserver.mcp.internal.decodeBody(response);

            test.verifyEqual(response.id, 1);       
            test.verifyTrue(hasField(response,'result.resources'));
            test.verifyEqual(numel(response.result.resources),1,"Number of resources");

            validateWireEncoding(test,response.result.resources,false);
        end

        function toolsList(test)
            import prodserver.mcp.internal.hasField
            import prodserver.mcp.MCPConstants
            import matlab.unittest.constraints.IsSameSetAs

            % Get base request structure
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];

            % List all tools
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "tools/list",' ...
               '"params": { "cursor": "optional-cursor-value"}}'];
            [req, body] = test.applyProtocol(req, body);

            reqT = req;
            reqT.Method = "POST";  % Because there's a body
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = test.handle(reqT);
            response = prodserver.mcp.internal.decodeBody(response);

            test.verifyEqual(response.id, 1);
            test.verifyTrue(hasField(response,'result.tools'));
            test.verifyEqual(numel(response.result.tools),numel(test.toolNames),"Number of tools");
            test.verifyThat(string({response.result.tools.name}),IsSameSetAs(test.toolNames));
        end

        function notStreamable(test)
        % Streamable HTTP not supported. Must proactively reject it. 
            import prodserver.mcp.MCPConstants


            % Get base request structure
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];

            % Server MUST return 405 in order for clients to know that
            % Streamable HTTP not support. This is part of the protocol.
            reqT = req;
            reqT.Method = "GET";  % Expecting an error
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, 0}];
            response = test.handle(reqT);
            test.verifyEqual(response.HttpCode,405);
        end

        function errorResult(test)
        end

        function resourceContent(test)
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            % Get base request structure
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];

            body = [...
                '{' ...
                '    "jsonrpc": "2.0",' ...
                '    "id": 1,'...
                '    "method": "tools/call",'...
                '    "params": {'...
                '        "name": "read_mcp_resource",'...
                '        "arguments": {'...
                '           "uri": "' char(MCPConstants.WireEncodingResourceURI) '"'...
                '        }'...
                '    }'...
                '}'
                ];
            [req, body] = test.applyProtocol(req, body);
            reqT = req;
            reqT.Method = "POST";  % Because there's a body
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = test.handle(reqT);
            response = decodeResponse(test,reqT,response);

            % Expecting content and structuredContent
            test.verifyEqual(response.id, 1);
            test.verifyTrue(hasField(response, 'result.content'));
            test.verifyTrue(hasField(response, 'result.structuredContent'));

            % Get encoding
            toolEncoding = prodserver.mcp.jsonrpc.toolEncoding("primeSequence", ...
                defFile=test.definitionFile);

            if toolEncoding == prodserver.mcp.WireEncoding.JSON
                txtClass = 'char';
            else
                txtClass = 'string';
            end

            test.verifyEqual(...
                class(response.result.structuredContent.contents.uri), ...
                txtClass);

            test.verifyEqual(...
                class(response.result.structuredContent.contents.mimeType), ...
                txtClass);

            test.verifyEqual(response.result.structuredContent.contents.uri,...
                feval(txtClass,MCPConstants.WireEncodingResourceURI)); %#ok<FVAL>
            test.verifyEqual(response.result.structuredContent.contents.mimeType, ...
                feval(txtClass,'text/plain')); %#ok<FVAL>
            test.verifyEqual(nnz(contains(response.result.content.text, ...
                MCPConstants.WireEncodingResourceURI)),1);
        end

        function content(test)
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            % Get base request structure
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];

            % Get encoding
            toolEncoding = prodserver.mcp.jsonrpc.toolEncoding("primeSequence", ...
                defFile=test.definitionFile);

            % Call primeSequence requesting 13 Eisenstein primes.
            body = [...
'{' ...
'    "jsonrpc": "2.0",' ...
'    "id": 1,'...
'    "method": "tools/call",'...
'    "params": {'...
'        "name": "primeSequence",'...
'        "arguments": {'...
'           "n": 13,'...
'           "type": "Eisenstein"'...
'        }'...
'    }'...
'}'
];
            [req, body] = test.applyProtocol(req, body);
            reqT = req;
            reqT.Method = "POST";  % Because there's a body
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = test.handle(reqT);
            response = decodeResponse(test,reqT,response);

            % Expecting content and structuredContent
            test.verifyEqual(response.id, 1);
            test.verifyTrue(hasField(response, 'result.content'));
            test.verifyTrue(hasField(response, 'result.structuredContent'));

            % primeSequence returns a row vector. MATLAB's native JSON 
            % encoding turns vectors into columns by default (orientation
            % is lost).
            expected.seq = primeSequence(13,"Eisenstein");
            if toolEncoding == prodserver.mcp.WireEncoding.JSON
                expected.seq = expected.seq';
            end
            test.verifyEqual(response.result.structuredContent,expected);

            % content should be a structure with fields "type" and "text"
            % (in this case). The type should be 'text' and the text should
            % be a JSON-encoded string of the structuredContent.
            test.verifyTrue(hasField(response.result.content,'type'), ...
                "Missing type field");
            test.verifyEqual(response.result.content.type,'text');
            test.verifyTrue(hasField(response.result.content,'text'), ...
                "Missing text field");

            % Since HTTP interface sends all strings as char
            enc = prodserver.mcp.jsonrpc.mcpEncode(toolEncoding,expected);
            txt = jsonencode(enc{1});
            test.verifyEqual(response.result.content.text, txt);
        end

        % Three former tests stood here -- server/discover, the Mcp-Method
        % header mismatch, and a _meta missing clientCapabilities -- each
        % opening with assumeEqual(test.protocol, "2026-07-28"). They are now
        % tHandlerV20260728, parameterized by nothing. Nothing about them was
        % ever per-protocol: the behaviour exists in exactly one revision, so
        % the parameter had no second value it could take and every case but
        % one was reported incomplete. This suite is filter-free as a result,
        % which is what makes an incomplete here worth reading.

        function notificationsAreAcceptedAndDropped(test)
        % Stage B of the pipeline: a notification receives no response at all
        % (MUST NOT in both specs), so mcpHandler acknowledges it with 202 and
        % an empty body. Notification handling is protocol-independent by
        % design, which is why no _meta and no session id appear here.
        %
        % The carve-out must sit ahead of BOTH the envelope check and protocol
        % detection. A notification legitimately has no id, so validateEnvelope
        % would reject it as -32600; and a 2026-07-28 notification legitimately
        % carries no _meta, so detection would reject it as unattributable.
        % Each method below is a live 202 that proves one of those orderings.
            import prodserver.mcp.MCPConstants

            notifMethods = ["notifications/initialized", ...
                            "notifications/cancelled", ...
                            "notifications/somethingWeDoNotKnow"];

            for m = notifMethods
                req = test.request;
                req.Headers = [req.Headers; ...
                    {MCPConstants.ContentType, 'application/json'}];

                % No id, and deliberately no protocol envelope of either era.
                body = char("{""jsonrpc"": ""2.0"", ""method"": """ + m + """}");

                reqT = req;
                reqT.Method = "POST";
                reqT.Path = "/prime/mcp";
                reqT.Headers = [reqT.Headers; ...
                    {MCPConstants.ContentLength, numel(body)}];
                reqT.Body = unicode2native(body,"UTF-8");
                response = test.handle(reqT);

                test.verifyEqual(response.HttpCode, 202, ...
                    "202 Accepted expected for " + m);
                test.verifyEmpty(response.Body, ...
                    "A notification must receive no response body: " + m);
            end
        end

        function notificationWithParamsStillAccepted(test)
        % notifications/cancelled carries params; they must not drag it into
        % the request path.
            import prodserver.mcp.MCPConstants

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}];
            body = ['{ "jsonrpc": "2.0", "method": "notifications/cancelled",' ...
                '"params": { "requestId": 42, "reason": "user aborted" } }'];

            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");

            % cancelled logs the reason to stdout; evalc keeps that out of the
            % test output while still returning the response.
            [log, response] = evalc( ...
                "prodserver.mcp.internal.mcpHandler(reqT)");
            prodserver.mcp.test.verifyConformantResponse(test, response);

            test.verifyEqual(response.HttpCode, 202);
            test.verifyEmpty(response.Body);
            test.verifyTrue(contains(log, "user aborted"), ...
                "The cancellation reason should have been logged");
        end

        function emptyBodyIsInvalidRequest(test)
        % Stage A, strict mode: an empty POST body is -32600 over HTTP 400,
        % not a -32603/500 from a raw MATLAB error falling through.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}];

            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, 0}];
            reqT.Body = uint8.empty(1,0);
            response = test.handle(reqT);

            test.verifyEqual(response.HttpCode, 400);
            decoded = prodserver.mcp.internal.decodeBody(response);
            test.assertTrue(hasField(decoded,'error.code'));
            test.verifyEqual(decoded.error.code, -32600);

            % Asserted on the wire, not on the decoded struct: JSON null
            % round-trips back through jsondecode as [], so only the raw body
            % can show that the id member is present and null rather than
            % missing altogether.
            test.verifyTrue(contains(native2unicode(response.Body,"UTF-8"), ...
                '"id":null'), ...
                "A request with no readable id must echo id as JSON null");
        end

        function malformedJsonIsParseError(test)
        % Stage A, strict mode: -32700 over HTTP 400.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}];
            body = '{ "jsonrpc": "2.0", "id": 1, "method": ';

            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = test.handle(reqT);

            test.verifyEqual(response.HttpCode, 400);
            decoded = prodserver.mcp.internal.decodeBody(response);
            test.assertTrue(hasField(decoded,'error.code'));
            test.verifyEqual(decoded.error.code, -32700);
            test.verifyTrue(contains(native2unicode(response.Body,"UTF-8"), ...
                '"id":null'), ...
                "An unparseable body has no id to echo, so it must be null");
        end

        function unsupportedMediaTypeIs415(test)
        % Stage A, strict mode: we simply do not speak this media type.
            import prodserver.mcp.MCPConstants

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'text/plain'}];
            body = 'jsonrpc 2.0 please';

            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = test.handle(reqT);

            test.verifyEqual(response.HttpCode, 415);
        end

        function requestWithoutIdIsInvalidRequest(test)
        % Stage B': a non-notification method with no id is a malformed
        % request. The carve-out above is what keeps this from catching
        % notifications, which legitimately have none.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}];
            body = '{ "jsonrpc": "2.0", "method": "tools/list" }';
            [req, body] = test.applyProtocol(req, body);

            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = test.handle(reqT);

            test.verifyEqual(response.HttpCode, 400);
            decoded = prodserver.mcp.internal.decodeBody(response);
            test.assertTrue(hasField(decoded,'error.code'));
            test.verifyEqual(decoded.error.code, -32600);
        end

        function wrongJsonrpcVersionIsInvalidRequest(test)
        % Stage B': 'jsonrpc' must be the string "2.0".
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}];
            body = '{ "jsonrpc": "1.0", "id": 1, "method": "tools/list" }';
            [req, body] = test.applyProtocol(req, body);

            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = test.handle(reqT);

            test.verifyEqual(response.HttpCode, 400);
            decoded = prodserver.mcp.internal.decodeBody(response);
            test.assertTrue(hasField(decoded,'error.code'));
            test.verifyEqual(decoded.error.code, -32600);
            test.verifyEqual(decoded.id, 1, ...
                "The id parsed fine, so it must still be echoed");
        end

        function batchRequestIsInvalidRequest(test)
        % Stage B': a JSON-RPC batch is not supported, and must be refused
        % as a malformed request object rather than crashing the handler.
        %
        % tValidateEnvelope already covers the batch in isolation. This test
        % exists because the rejection used to be undone on the way out: a
        % batch decodes to a struct ARRAY, and responseId -- reached through
        % handleError while reporting the -32600 -- read jrpc.id without an
        % isscalar guard, so the field access expanded to a comma-separated
        % list and raised MATLAB:maxrhs. That escaped mcpHandler's own catch
        % and surfaced to Production Server as a raw MATLAB error instead of
        % the 400 the envelope check had already decided on. Only an
        % end-to-end POST can see that, which is why it lives here.
        %
        % No applyProtocol: the batch is refused before protocol detection,
        % so there is no envelope to add -- and the 2026-07-28 branch would
        % itself fail trying to graft _meta onto a struct array.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}];
            body = ['[{"jsonrpc":"2.0","id":1,"method":"tools/list"},' ...
                    '{"jsonrpc":"2.0","id":2,"method":"tools/list"}]'];

            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = test.handle(reqT);

            test.verifyEqual(response.HttpCode, 400);
            decoded = prodserver.mcp.internal.decodeBody(response);
            test.assertTrue(hasField(decoded,'error.code'));
            test.verifyEqual(decoded.error.code, -32600);
            % No single request to answer, so JSON-RPC requires a null id.
            test.verifyTrue(hasField(decoded,'id'), ...
                "A response must carry an id member even when it is null");
            test.verifyTrue(isempty(decoded.id) || all(isnan(decoded.id)), ...
                "A batch has no one id to echo; it must come back null");
        end

        function singleElementBatchIsInvalidRequest(test)
        % ND13: a one-element batch decodes to the same scalar struct as
        % the bare request, so it got past the struct-array check above and
        % its element was answered as a single request. Otherwise valid for
        % the revision under test, so the array is the only thing wrong.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}];
            inner = '{"jsonrpc":"2.0","id":3,"method":"tools/list"}';
            [req, inner] = test.applyProtocol(req, inner);
            body = [' [' char(inner) ']'];

            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = test.handle(reqT);

            test.verifyEqual(response.HttpCode, 400, ...
                native2unicode(response.Body,"UTF-8"));
            decoded = prodserver.mcp.internal.decodeBody(response);
            test.assertTrue(hasField(decoded,'error.code'));
            test.verifyEqual(decoded.error.code, -32600);
            test.verifyFalse(hasField(decoded,'result'));
        end

        function malformedCancelledIsStillAccepted(test)
        % XD10: badly typed members used to throw inside cancelled, and the
        % catch answered the notification with a 500 and a JSON body.
            import prodserver.mcp.MCPConstants

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}];
            body = ['{ "jsonrpc": "2.0", "method": "notifications/cancelled",' ...
                '"params": { "requestId": [1, 2], "reason": {"why": 1} } }'];

            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");

            [~, response] = evalc("prodserver.mcp.internal.mcpHandler(reqT)");
            prodserver.mcp.test.verifyConformantResponse(test, response);

            test.verifyEqual(response.HttpCode, 202, ...
                native2unicode(response.Body,"UTF-8"));
            test.verifyEmpty(response.Body);
        end
    end

end
