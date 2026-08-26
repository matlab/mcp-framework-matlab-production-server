classdef tSchemaDeployCI < MCPCaller
% Test deployment and invocation of MCP tools built from schema-generated
% definitions for functions without argument blocks.

% Copyright 2026 The MathWorks, Inc.

    methods (TestMethodSetup)
        function scratchSpace(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            tfolder = TemporaryFolderFixture;
            applyFixture(test, tfolder);
            setFolders(test, temp=tfolder.Folder);

            % Add schemaTools to path
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods (Test)

        function singleToolNoBlock(test)
            fcn = "schemaComputeNoBlock";
            archive = "schemaDeploySingle";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            % Generate schema via observation
            defs = prodserver.mcp.schema(fcn, ...
                @() callSchemaCompute(), encoding="Invertible");

            % Build archive with schema-generated definition
            ctf = prodserver.mcp.build(fcn, definition=defs, ...
                folder=test.tempFolder, archive=archive, ...
                encoding="Invertible");

            % Deploy
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            % Verify tool exists
            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            % Call and verify
            x = 5.0; y = 3.0; z = 2.0;
            [eTotal, eProduct, eReport] = schemaComputeNoBlock(x, y, z);
            [aTotal, aProduct, aReport] = prodserver.mcp.call(...
                endpoint, fcn, x, y, z);

            test.verifyEqual(aTotal, eTotal, "total");
            test.verifyEqual(aProduct, eProduct, "product");
            test.verifyEqual(aReport, eReport, "report");
        end

        function multiToolNoBlock(test)
            fcns = ["schemaComputeNoBlock", "schemaVectorNoBlock"];
            archive = "schemaDeployMulti";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            % Generate schema via observation
            defs = prodserver.mcp.schema(fcns, ...
                @() exerciseTools(), encoding="Invertible");

            % Build archive with schema-generated definitions
            ctf = prodserver.mcp.build(fcns, definition=defs, ...
                folder=test.tempFolder, archive=archive, ...
                encoding="Invertible");

            % Deploy
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            % Verify both tools exist
            for n = 1:numel(fcns)
                tf = prodserver.mcp.exist(endpoint, fcns(n), "Tool", ...
                    delay=10, retry=5);
                test.verifyTrue(tf, fcns(n) + " not found at " + endpoint);
            end

            % Call schemaComputeNoBlock
            x = 4.0; y = 5.0; z = 6.0;
            [eTotal, eProduct, eReport] = schemaComputeNoBlock(x, y, z);
            [aTotal, aProduct, aReport] = prodserver.mcp.call(...
                endpoint, "schemaComputeNoBlock", x, y, z);

            test.verifyEqual(aTotal, eTotal, "schemaComputeNoBlock total");
            test.verifyEqual(aProduct, eProduct, "schemaComputeNoBlock product");
            test.verifyEqual(aReport, eReport, "schemaComputeNoBlock report");

            % Call schemaVectorNoBlock
            values = [1.0, 2.0, 3.0]; scale = 2.0;
            [eMag, eNorm, eCount] = schemaVectorNoBlock(values, scale);
            [aMag, aNorm, aCount] = prodserver.mcp.call(...
                endpoint, "schemaVectorNoBlock", values, scale);

            test.verifyEqual(aMag, eMag, "magnitude", AbsTol=1e-12);
            test.verifyEqual(aNorm, eNorm, "normalized", AbsTol=1e-12);
            test.verifyEqual(aCount, eCount, "count");
        end

        function toolsListable(test)
            fcns = ["schemaComputeNoBlock", "schemaVectorNoBlock"];
            archive = "schemaDeployList";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            % Generate schema and build
            defs = prodserver.mcp.schema(fcns, ...
                @() exerciseTools());
            ctf = prodserver.mcp.build(fcns, definition=defs, ...
                folder=test.tempFolder, archive=archive);

            % Deploy
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            % Wait for tools to be available
            for n = 1:numel(fcns)
                tf = prodserver.mcp.exist(endpoint, fcns(n), "Tool", ...
                    delay=10, retry=5);
                test.verifyTrue(tf, fcns(n) + " not found at " + endpoint);
            end

            % List tools
            tools = prodserver.mcp.list(endpoint, "Tool");
            toolNames = string(cellfun(@(t)t.name, tools, ...
                UniformOutput=false));
            for n = 1:numel(fcns)
                test.verifyTrue(ismember(fcns(n), toolNames), ...
                    fcns(n) + " not in list");
            end
        end

    end
end

function callSchemaCompute()
    [~,~,~] = schemaComputeNoBlock(1.0, 2.0, 3.0);
end

function exerciseTools()
    [~,~,~] = schemaComputeNoBlock(1.0, 2.0, 3.0);
    [~,~,~] = schemaVectorNoBlock([1.0, 2.0, 3.0], 2.0);
end
