classdef tmcpHandler < MCPHandlerBase 
% Wide selection of tests for the mcpHandler function. 

% Copyright 2026 The MathWorks, Inc.

    methods (TestClassSetup)

        function prepareTools(test)
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

            defineTools(test,test.fcnNames,test.toolNames);
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

                % Not what we'd find in a real deployed tool, but validates
                % that content was written to MAT file.
                test.verifyEqual(string(result.contents.text), ...
                    MCPConstants.WireEncodingResource.contents);
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

        function errorResult(test)
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
                '           "url": "' char(MCPConstants.WireEncodingResourceURI) '"'...
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
            response = prodserver.mcp.internal.decodeBody(response);

            % Expecting content and structuredContent
            test.verifyEqual(response.id, 1);
            test.verifyTrue(hasField(response, 'result.content'));
            test.verifyTrue(hasField(response, 'result.structuredContent'));
            test.verifyEqual(response.result.structuredContent.contents.uri,...
                MCPConstants.WireEncodingResourceURI);
            test.verifyEqual(response.result.structuredContent.contents.mimeType, ...
                "text/plain");
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
            response = prodserver.mcp.internal.decodeBody(response);

            % Expecting content and structuredContent
            test.verifyEqual(response.id, 1);
            test.verifyTrue(hasField(response, 'result.content'));
            test.verifyTrue(hasField(response, 'result.structuredContent'));

            % Result is a column vector.
            expected.seq = primeSequence(13,"Eisenstein");
            test.verifyEqual(response.result.structuredContent,expected);
            % Since HTTP interface sends all strings as char
            test.verifyEqual(response.result.content.text, ...
                prodserver.mcp.jsonrpc.mcpWireEncode(expected));
        end
    end

end
