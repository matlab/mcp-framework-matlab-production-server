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

            % Call primeSequence with a string as the first input, which
            % its schema says is a number. Once, this reached the tool as a
            % char array, which MATLAB treated as an array of character
            % codes. Now the server rejects it before the tool runs, as the
            % serving revision says: -32602 under 2025-06-18, a tool
            % execution error the model can correct under 2026-07-28.
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

            % Add the protocol-specific envelope (a 2025-06-18 session header
            % or 2026-07-28 _meta + version header) so the request is
            % detected as the protocol under test.
            [req, body] = test.applyProtocol(req, body);

            reqT = req;
            reqT.Method = "POST";  % Because there's a body
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = prodserver.mcp.internal.mcpHandler(reqT);

            % Neither answer is an HTTP error.
            test.verifyEqual(response.HttpCode, 200);
            response = decodeResponse(test,reqT,response);
            test.verifyEqual(response.id, 1);

            if prodserver.mcp.protocol.inputErrorsAreToolErrors(test.protocol)
                test.verifyTrue(hasField(response, 'result.isError'));
                test.verifyEqual(response.result.isError,true,"isError not true");
                test.verifyTrue(hasField(response.result.content,'text'), ...
                    "text field missing");
                text = string(response.result.content.text);
            else
                test.verifyFalse(hasField(response, 'result'));
                test.assertTrue(hasField(response, 'error.code'));
                test.verifyEqual(response.error.code, ...
                    double(MCPConstants.ErrorInvalidParams));
                text = string(response.error.message);
            end
            % The schema is an array of numbers under JSON encoding, a
            % wrapper or bare number under Invertible; either way the
            % message names the argument and what was wrong with it.
            test.verifySubstring(text, "Argument 'n': ", ...
                "The message must name the argument");
            test.verifySubstring(text, "expected number, got string", ...
                "The message must say what was wrong");
        end
    end

end