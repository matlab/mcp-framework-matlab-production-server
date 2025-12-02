classdef tmcpHandler < HandlerBase

    methods (TestClassSetup)
        function prepareTools(test)
            % Assume defineForMCP is working. It has its own tests. :-)
            % Better decoupling requires a lot of (probably unnecessary)
            % work.
            test.fcnNames = ["plotTrajectoriesMCP","primeSequence"];
            test.toolNames = ["plotTrajectories","primeSequence"];

            defineTools(test,test.fcnNames,test.toolNames);
        end
    end

    methods(Test)

        function toolsList(test)
            import prodserver.mcp.internal.mcpHandler
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
            reqT.Path = "http://localhost:9910/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = prodserver.mcp.internal.mcpHandler(reqT);
            response = prodserver.mcp.internal.decodeBody(response);

            test.verifyEqual(response.id, 1);
            test.verifyTrue(hasField(response,'result.tools'));
            test.verifyEqual(numel(response.result.tools),2,"Number of tools");
            test.verifyThat(string({response.result.tools.name}),IsSameSetAs(test.toolNames));
        end

        function notStreamable(test)
        % Streamable HTTP not supported. Must proactively reject it. 
            import prodserver.mcp.internal.mcpHandler
            import prodserver.mcp.MCPConstants


            % Get base request structure
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];

            % Server MUST return 405 in order for clients to know that
            % Streamable HTTP not support. This is part of the protocol.
            reqT = req;
            reqT.Method = "GET";  % Expecting an error
            reqT.Path = "http://localhost:9910/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, 0}];
            response = prodserver.mcp.internal.mcpHandler(reqT);
            test.verifyEqual(response.HttpCode,405);
        end

        function errorResult(test)
        end

        function content(test)
            import prodserver.mcp.internal.mcpHandler
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
            reqT.Path = "http://localhost:9910/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = prodserver.mcp.internal.mcpHandler(reqT);
            response = prodserver.mcp.internal.decodeBody(response);

            % Expecting content and structuredContent
            test.verifyEqual(response.id, 1);
            test.verifyTrue(hasField(response, 'result.content'));
            test.verifyTrue(hasField(response, 'result.structuredContent'));

            % Result is a column vector.
            expected.seq = primeSequence(13,"Eisenstein")';
            test.verifyEqual(response.result.structuredContent,expected);
            % Since HTTP interface sends all strings as char
            test.verifyEqual(response.result.content.text, ...
                jsonencode(expected.seq));
        end
    end

end
