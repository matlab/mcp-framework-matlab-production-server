classdef tSchemaBI < matlab.unittest.TestCase & ...
        prodserver.mcp.test.mixin.MCPServer
% Test build and execution of MCP server using schema-generated definitions
% for functions without argument blocks.

% Copyright 2026 The MathWorks, Inc.

    properties
        tempFolder
        server
        fcns
    end

    methods(TestClassSetup)
        function buildServer(test)
        %buildServer Build the MCP server using build(example=...) API.

            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            import prodserver.mcp.MCPConstants

            % Put the schema tools on the path
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());

            % Create a temporary folder for all the deployment artifacts
            tempDir = TemporaryFolderFixture(WithSuffix="schemaBI");
            test.applyFixture(tempDir);
            test.tempFolder = tempDir.Folder;

            % Put the temporary folder on the path so that the handler can
            % load the definition file.
            test.applyFixture(PathFixture(test.tempFolder));

            % Two no-block functions
            test.fcns = ["schemaComputeNoBlock", "schemaVectorNoBlock"];

            % Build using the example= API (schema generation is internal)
            test.server = "schemaBI";
            ctf = prodserver.mcp.build(test.fcns, ...
                example=@() exerciseTools(), ...
                folder=test.tempFolder, archive=test.server, ...
                encoding="Invertible");

            test.verifyTrue(startsWith(ctf, test.tempFolder), ctf);
        end
    end

    methods (TestMethodSetup)
        function switchContext(~)
            % Clear tool definition cache.
            prodserver.mcp.handler.toolServices(action="clear");
        end
    end

    methods(Test)

        function definitionFileExists(test)
            import prodserver.mcp.MCPConstants
            defFile = fullfile(test.tempFolder, MCPConstants.DefinitionFile);
            test.verifyEqual(exist(defFile, "file"), 2, defFile);
        end

        function toolCountCorrect(test)
            import prodserver.mcp.MCPConstants
            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);
            % +1 for read_mcp_resource
            test.verifyEqual(numel(def.tools), numel(test.fcns)+1);
        end

        function toolNamesCorrect(test)
            import prodserver.mcp.MCPConstants
            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);
            names = cellfun(@(t)string(t.name), def.tools);
            for n = 1:numel(test.fcns)
                test.verifyTrue(ismember(test.fcns(n), names), ...
                    test.fcns(n) + " not in definition");
            end
        end

        function signaturesPresent(test)
            import prodserver.mcp.MCPConstants
            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);
            for n = 1:numel(test.fcns)
                test.verifyTrue(isfield(def.(MCPConstants.SignatureVariable), ...
                    test.fcns(n)), test.fcns(n) + " signature missing");
            end
        end

        function listToolsViaHandler(test)
            import prodserver.mcp.MCPConstants

            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "tools/list",' ...
                '"params": { "cursor": "optional-cursor-value"}}'];
            req = mcpRequest(test, test.server, body=body);
            resp = handleRequest(test, req);

            test.verifyFalse(isfield(resp, 'error'), "Error field present");
            test.verifyTrue(isfield(resp, 'result'), "Result field missing");

            tools = resp.result.tools;
            if iscell(tools)
                names = cellfun(@(t)string(t.name), tools);
            else
                names = arrayfun(@(t)string(t.name), tools);
            end
            for n = 1:numel(test.fcns)
                test.verifyTrue(ismember(test.fcns(n), names), ...
                    test.fcns(n) + " not in tools/list");
            end
        end

        function callSchemaComputeNoBlock(test)
            import prodserver.mcp.MCPConstants

            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            fcn = "schemaComputeNoBlock";
            x = 1.0; y = 2.0; z = 3.0;
            [eTotal, eProduct, eReport] = schemaComputeNoBlock(x, y, z);

            t = findDefinition(fcn, def);
            s = def.signatures;

            body = jsonToolCall(test, fcn, 2, t, s, x, y, z);
            req = mcpRequest(test, test.server, body=body);
            resp = handleRequest(test, req);

            test.verifyFalse(isfield(resp, 'error'), "Error field present");
            test.verifyTrue(isfield(resp, 'result'), "Result field missing");

            sc = resp.result.structuredContent;
            test.verifyEqual(sc.total, eTotal, "total");
            test.verifyEqual(sc.product, eProduct, "product");
            test.verifyEqual(string(sc.report), eReport, "report");
        end

        function callSchemaVectorNoBlock(test)
            import prodserver.mcp.MCPConstants

            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            fcn = "schemaVectorNoBlock";
            values = [1.0, 2.0, 3.0]; scale = 2.0;
            [eMag, eNorm, eCount] = schemaVectorNoBlock(values, scale);

            t = findDefinition(fcn, def);
            s = def.signatures;

            body = jsonToolCall(test, fcn, 3, t, s, values, scale);
            req = mcpRequest(test, test.server, body=body);
            resp = handleRequest(test, req);

            test.verifyFalse(isfield(resp, 'error'), "Error field present");
            test.verifyTrue(isfield(resp, 'result'), "Result field missing");

            sc = resp.result.structuredContent;
            test.verifyEqual(sc.magnitude, eMag, "magnitude", AbsTol=1e-12);
            test.verifyEqual(sc.normalized, eNorm, "normalized", AbsTol=1e-12);
            test.verifyEqual(sc.count, eCount, "count");
        end

    end
end

function exerciseTools()
    [~,~,~] = schemaComputeNoBlock(1.0, 2.0, 3.0);
    [~,~,~] = schemaVectorNoBlock([1.0, 2.0, 3.0], 2.0);
end

function t = findDefinition(tool, def)
    tName = cellfun(@(t)string(t.name), def.tools);
    k = strcmp(tool, tName);
    t = def.tools{k};
end
