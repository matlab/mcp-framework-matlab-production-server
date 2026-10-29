classdef tRenameTool < prodserver.mcp.test.base.MCPHandlerBase
% Verify that defineForMCP applies the tool= name when a pre-built
% definition is provided (e.g. from example= or definition=).

% Copyright 2026 The MathWorks, Inc.

    properties (ClassSetupParameter)
        encoding = { prodserver.mcp.WireEncoding.JSON };
    end

    methods (TestClassSetup)

        function prepareTools(test, encoding)
            import matlab.unittest.fixtures.PathFixture

            test.applyFixture(prodserver.mcp.test.mixin.RequireExamples());

            test.applyFixture(PathFixture(...
                fullfile(prodserver.mcp.internal.packageFolder(), ...
                         "server","tools")));

            test.fcnNames = ["primeSequence", "read_mcp_resource"];
            test.toolNames = ["myCustomTool", "read_mcp_resource"];

            defs = prodserver.mcp.schema("primeSequence", ...
                @() primeSequence(5, "Eisenstein"), encoding=encoding);
            definition = num2cell(defs);
            definition{end+1} = [];

            def = prodserver.mcp.internal.defineForMCP( ...
                test.toolNames, test.fcnNames, ...
                definition=definition, encoding=encoding);

            import prodserver.mcp.MCPConstants
            test.definitionFile = fullfile(test.tempFolder, ...
                MCPConstants.DefinitionFile);
            d.(MCPConstants.DefinitionVariable) = def;
            d.(MCPConstants.ResourceVariable) = ...
                prodserver.mcp.internal.resourceDefinition( ...
                    {MCPConstants.WireEncodingResource});
            save(test.definitionFile, "-struct", "d");

            prodserver.mcp.handler.toolServices(action="clear");
        end
    end

    methods (Test)

        function tToolListShowsCustomName(test)
            import prodserver.mcp.MCPConstants

            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];

            body = '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}';
            [req, body] = test.applyProtocol(req, body);

            req.Method = "POST";
            req.Path = "/test/mcp";
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            req.Body = unicode2native(body, "UTF-8");

            response = prodserver.mcp.internal.mcpHandler(req);
            response = prodserver.mcp.internal.decodeBody(response);

            if iscell(response.result.tools)
                names = cellfun(@(t)string(t.name), response.result.tools);
            else
                names = arrayfun(@(t)string(t.name), response.result.tools);
            end
            test.verifyTrue(ismember("myCustomTool", names), ...
                "Custom tool name should appear in tools/list");
            test.verifyFalse(ismember("primeSequence", names), ...
                "Original function name should not appear in tools/list");
        end

        function tToolCallByCustomName(test)
            import prodserver.mcp.MCPConstants

            reqT = test.createRequest("myCustomTool", test.server, ...
                "n", 3, "type", "Eisenstein");
            response = prodserver.mcp.internal.mcpHandler(reqT);
            result = test.decodeResponse(reqT, response);

            test.verifyTrue(isfield(result, 'result'), ...
                "Response should have a result field");
            test.verifyFalse(isfield(result, 'error'), ...
                "Response should not have an error");
        end

        function tSignatureKeyMatchesCustomName(test)
            import prodserver.mcp.MCPConstants

            def = load(test.definitionFile);
            def = def.(MCPConstants.DefinitionVariable);

            test.verifyTrue(isfield(def.signatures, "myCustomTool"), ...
                "Signature should be keyed by custom tool name");
            test.verifyFalse(isfield(def.signatures, "primeSequence"), ...
                "Signature should not be keyed by original function name");
            test.verifyEqual( ...
                string(def.signatures.myCustomTool.function), ...
                "primeSequence", ...
                "Signature should map to the original function");
        end

    end

end
