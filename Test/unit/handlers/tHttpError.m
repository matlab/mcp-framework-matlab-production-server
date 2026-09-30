classdef tHttpError < prodserver.mcp.test.base.MCPHandlerBase
% Provoke and then handle HTTP errors correctly. 

% Copyright 2026 The MathWorks, Inc.

    properties (ClassSetupParameter)
        encoding = { prodserver.mcp.WireEncoding.JSON, ...
            prodserver.mcp.WireEncoding.Invertible };
    end

    methods (TestClassSetup)

        function prepareTools(test,encoding)
            import matlab.unittest.fixtures.PathFixture

            % Add examples to the path
            test.applyFixture(prodserver.mcp.test.mixin.RequireExamples);

            % Add server tools to the path
            test.applyFixture(PathFixture(...
                fullfile(prodserver.mcp.internal.packageFolder(), ...
                "server","tools")));

            % Assume defineForMCP is working. It has its own tests. :-)
            % Better decoupling requires a lot of (probably unnecessary)
            % work.
            test.fcnNames = ["primeSequence","read_mcp_resource"];
            test.toolNames = ["primeSequence","read_mcp_resource"];

            defineTools(test,test.fcnNames,test.toolNames,encoding=encoding);
        end
    end

    methods(Test)
        function sendBadDataType(test)
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

            % Call primeSequence with a string as the first input. This
            % should raise an error about scalar input, since converting 
            % "thirteen" to a double (via HTTP, which first turns it into
            % a char array) turns it into an array of ASCII values.
            body = [...
                '{' ...
                '    "jsonrpc": "2.0",' ...
                '    "id": 1,'...
                '    "method": "tools/call",'...
                '    "params": {'...
                '        "name": "primeSequence",'...
                '        "arguments": {'...
                '           "n": "thirteen",'...
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

            % MATLAB error IS NOT an HTTP error. Expect 200-level return
            % code.
            test.verifyEqual(response.HttpCode, 200);

            % Body should contain isError field set to true and a structure
            % describing the error.
            response = decodeResponse(test,reqT,response);

            test.verifyEqual(response.id, 1);
            test.verifyTrue(hasField(response, 'result'));
            test.verifyTrue(hasField(response, 'result.isError'));
            test.verifyEqual(response.result.isError,true,"isError not true");
            test.verifyTrue(hasField(response, 'result.content'));
            test.verifyTrue(isstruct(response.result.content), ...
                "result.content not struct");
            test.verifyTrue(hasField(response.result.content,'text'), ...
                "text field missing");
            test.verifyTrue(contains(response.result.content.text,"Size") && ...
                contains(response.result.content.text,"scalar"), ...
                "Unexpected error message text");

            % Expecting 

        end
    end

end