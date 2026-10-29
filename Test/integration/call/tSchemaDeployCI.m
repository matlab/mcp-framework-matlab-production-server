classdef tSchemaDeployCI < prodserver.mcp.test.base.MCPCaller
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

            % Expected
            x = 5.0; y = 3.0; z = 2.0;
            [eTotal, eProduct, eReport] = schemaComputeNoBlock(x, y, z);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                % Verify tool exists
                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found at " + endpoint + " [" + p + "]");

                % Call and verify
                [aTotal, aProduct, aReport] = prodserver.mcp.call(...
                    endpoint, fcn, x, y, z);

                test.verifyEqual(aTotal, eTotal, "total [" + p + "]");
                test.verifyEqual(aProduct, eProduct, "product [" + p + "]");
                test.verifyEqual(aReport, eReport, "report [" + p + "]");
            end
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

            % Expected
            x = 4.0; y = 5.0; z = 6.0;
            [eTotal, eProduct, eReport] = schemaComputeNoBlock(x, y, z);

            values = [1.0, 2.0, 3.0]; scale = 2.0;
            [eMag, eNorm, eCount] = schemaVectorNoBlock(values, scale);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                % Verify both tools exist
                for n = 1:numel(fcns)
                    tf = prodserver.mcp.exist(endpoint, fcns(n), "Tool", ...
                        delay=10, retry=5, protocol=p);
                    test.verifyTrue(tf, ...
                        fcns(n) + " not found [" + p + "]");
                end

                % Call schemaComputeNoBlock
                [aTotal, aProduct, aReport] = prodserver.mcp.call(...
                    endpoint, "schemaComputeNoBlock", x, y, z);

                test.verifyEqual(aTotal, eTotal, ...
                    "schemaComputeNoBlock total [" + p + "]");
                test.verifyEqual(aProduct, eProduct, ...
                    "schemaComputeNoBlock product [" + p + "]");
                test.verifyEqual(aReport, eReport, ...
                    "schemaComputeNoBlock report [" + p + "]");

                % Call schemaVectorNoBlock
                [aMag, aNorm, aCount] = prodserver.mcp.call(...
                    endpoint, "schemaVectorNoBlock", values, scale);

                test.verifyEqual(aMag, eMag, ...
                    "magnitude [" + p + "]", AbsTol=1e-12);
                test.verifyEqual(aNorm, eNorm, ...
                    "normalized [" + p + "]", AbsTol=1e-12);
                test.verifyEqual(aCount, eCount, "count [" + p + "]");
            end
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

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                % Wait for tools to be available
                for n = 1:numel(fcns)
                    tf = prodserver.mcp.exist(endpoint, fcns(n), "Tool", ...
                        delay=10, retry=5, protocol=p);
                    test.verifyTrue(tf, ...
                        fcns(n) + " not found [" + p + "]");
                end

                % List tools
                tools = prodserver.mcp.list(endpoint, "Tool");
                toolNames = string(cellfun(@(t)t.name, tools, ...
                    UniformOutput=false));
                for n = 1:numel(fcns)
                    test.verifyTrue(ismember(fcns(n), toolNames), ...
                        fcns(n) + " not in list [" + p + "]");
                end
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
