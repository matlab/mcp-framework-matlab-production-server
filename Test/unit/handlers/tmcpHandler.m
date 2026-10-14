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

        function resourcesRead(test)
            import prodserver.mcp.internal.hasField
            import prodserver.mcp.MCPConstants

            % Get base request structure
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];

            % Make up a session ID
            id = matlab.lang.internal.uuid;
            req.Headers = [req.Headers; { MCPConstants.SessionId id} ];

            % Get the resource
            uri = char(MCPConstants.WireEncodingResourceURI);
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "resources/read",' ...
                '"params": { "uri": "' uri '"}}'];

            reqT = req;
            reqT.Method = "POST";  % Because there's a body
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = prodserver.mcp.internal.mcpHandler(reqT);
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

            % Make up a session ID
            id = matlab.lang.internal.uuid;
            req.Headers = [req.Headers; { MCPConstants.SessionId id} ];

            % List all resources
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "resources/list",' ...
                '"params": { "cursor": "optional-cursor-value"}}'];

            reqT = req;
            reqT.Method = "POST";  % Because there's a body
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = prodserver.mcp.internal.mcpHandler(reqT);
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

            % Make up a session ID
            id = matlab.lang.internal.uuid;
            req.Headers = [req.Headers; { MCPConstants.SessionId id} ];

            % List all tools
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "tools/list",' ...
               '"params": { "cursor": "optional-cursor-value"}}'];

            reqT = req;
            reqT.Method = "POST";  % Because there's a body
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = prodserver.mcp.internal.mcpHandler(reqT);
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
            response = prodserver.mcp.internal.mcpHandler(reqT);
            test.verifyEqual(response.HttpCode,405);
        end

        function resourceContent(test)
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            % Get base request structure
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];

            % Make up a session ID
            id = matlab.lang.internal.uuid;
            req.Headers = [req.Headers; { MCPConstants.SessionId id} ];

            % Call primeSequence requesting 13 Eisenstein primes.
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
            reqT = req;
            reqT.Method = "POST";  % Because there's a body
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = prodserver.mcp.internal.mcpHandler(reqT);
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

            % Make up a session ID
            id = matlab.lang.internal.uuid;
            req.Headers = [req.Headers; { MCPConstants.SessionId id} ];

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
            reqT = req;
            reqT.Method = "POST";  % Because there's a body
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = prodserver.mcp.internal.mcpHandler(reqT);
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

        function deleteTerminatesSession(test)
        % A real session-termination DELETE carries the Mcp-Session-Id
        % header and no JSON-RPC body. It must be acknowledged with 204 No
        % Content, echoing the session id exactly once.
            import prodserver.mcp.MCPConstants

            session = char(matlab.lang.internal.uuid);

            reqT = test.request;
            reqT.Method = "DELETE";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.SessionId session}; ...
                {MCPConstants.ContentLength, '0'}];
            response = prodserver.mcp.internal.mcpHandler(reqT);

            test.verifyEqual(response.HttpCode, 204);

            names = string(response.Headers(:,1));
            sessionRows = strcmpi(names, string(MCPConstants.SessionId));
            test.verifyEqual(nnz(sessionRows), 1, ...
                "Response must echo Mcp-Session-Id exactly once");
            test.verifyEqual(string(response.Headers{sessionRows,2}), ...
                string(session));
        end

        function deleteWithoutSessionIsBadRequest(test)
        % DELETE is a supported verb, so the refusal is about the request, not
        % the method: a DELETE with no session header cannot be attributed to
        % a session and is 400 Bad Request. 405 would be a lie -- it would
        % tell the client DELETE is never allowed on this resource, which is
        % the same signal GET uses to report there is no SSE transport.
            import prodserver.mcp.MCPConstants

            reqT = test.request;
            reqT.Method = "DELETE";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, '0'}];
            response = prodserver.mcp.internal.mcpHandler(reqT);

            test.verifyEqual(response.HttpCode, 400);

            % A transport-level refusal carries no JSON-RPC body.
            test.verifyEmpty(response.Body);
        end

        function unsupportedMethodIsProtocolError(test)
        % An unsupported MCP method is a protocol-level JSON-RPC error: it
        % is carried in the body as error.code == -32601 (method not found)
        % over HTTP 200, not surfaced as an HTTP 500 transport failure.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];
            id = matlab.lang.internal.uuid;
            req.Headers = [req.Headers; {MCPConstants.SessionId id}];

            body = ['{ "jsonrpc": "2.0", "id": 1, ' ...
                '"method": "resources/subscribe", "params": {} }'];

            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = prodserver.mcp.internal.mcpHandler(reqT);

            test.verifyEqual(response.HttpCode, 200);

            response = prodserver.mcp.internal.decodeBody(response);
            test.verifyTrue(hasField(response, "error.code"), ...
                "Protocol error must carry a JSON-RPC error.code");
            test.verifyEqual(response.error.code, ...
                MCPConstants.ErrorMethodNotFound);
            test.verifyFalse(hasField(response, "result"), ...
                "Protocol error must not carry a tool-style result");
        end
    end

end
