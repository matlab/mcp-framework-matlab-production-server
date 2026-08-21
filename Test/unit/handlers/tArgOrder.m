classdef tArgOrder < prodserver.mcp.test.base.MCPHandlerBase
% Test how mcpHandler manages JRPC's argument ordering.

% Copyright 2025-2026 The MathWorks, Inc.

    properties (ClassSetupParameter)
        encoding = { prodserver.mcp.WireEncoding.JSON, ...
            prodserver.mcp.WireEncoding.Invertible };
    end

    methods (TestClassSetup)

        function prepareTools(test,encoding)
            import matlab.unittest.fixtures.PathFixture

            % Add parameter tools to the path
            test.applyFixture(prodserver.mcp.test.mixin.RequireParamTools());

            % Add server tools to the path
            test.applyFixture(PathFixture(...
                fullfile(prodserver.mcp.internal.packageFolder(), ...
                         "server","tools")));

            % Provide both tool (wrapper) name and function name.
            test.fcnNames = ["orderMatters"];
            test.toolNames = ["orderMatters"];

            defineTools(test,test.fcnNames,test.toolNames,encoding=encoding);
        end
    end

    methods(Test)

        function inputOrder(test)
        % Send the inputs in an unexpected order.

            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            % Call function directly to get expected outputs.
            % Inputs in the correct order.
            a = 4; b = 12; c = 3; d = 7;
            [x,y,z] = orderMatters(a,b,c,d);

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

            % Call orderMatters with inputs out of order.
            body = [...
'{' ...
'    "jsonrpc": "2.0",' ...
'    "id": 1,'...
'    "method": "tools/call",'...
'    "params": {'...
'        "name": "orderMatters",'...
'        "arguments": {'...
'           "d": ' char(string(d)) ',' ...
'           "a": ' char(string(a)) ','...
'           "b": ' char(string(b)) ',' ...
'           "c": ' char(string(c))  ...
'        }'...
'    }'...
'}'
];
            reqT = req;
            reqT.Method = "POST";  % Because there's a body
            reqT.Path = "/orderMatters/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = prodserver.mcp.internal.mcpHandler(reqT);
            response = decodeResponse(test,reqT,response);

            % Expecting content and structuredContent
            test.verifyEqual(response.id, 1);
            test.verifyTrue(hasField(response, 'result.content'));
            test.verifyTrue(hasField(response, 'result.structuredContent'));

            % Result is a column vector.
            expected.x = x; 
            expected.y = y;
            expected.z = z;
            test.verifyEqual(response.result.structuredContent,expected);
            % Since HTTP interface sends all strings as char
            enc = prodserver.mcp.jsonrpc.mcpEncode(toolEncoding,expected);
            txt = jsonencode(enc{1});
            test.verifyEqual(response.result.content.text, txt);
        end
    end
end
