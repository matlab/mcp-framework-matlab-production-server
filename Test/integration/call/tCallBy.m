classdef tCallBy < MCPCaller & ...
        prodserver.mcp.test.mixin.ExternalData
% Test explicit call-by-reference and call-by-value schema flags.

    methods (TestMethodSetup)
        function scratchSpace(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            % Temporary folder for intermediate / generated artifacts
            tfolder = TemporaryFolderFixture;
            applyFixture(test,tfolder);
            test.tempFolder = tfolder.Folder;
        end
    end

    methods(Test)

        function byValue(test)
        % Test x-call-by: value
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            % Requires parameter-focused test tools
            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireParamTools());
            test.toolFolder = rtt.toolFolder;

            % Uses x-call-by: value in schema for the return value, which
            % otherwise would be externalized, as it contains 289 elements,
            % which is over the limit of MCPConstants.MaxLiteralSize.
            fcn = "callByValue";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,fcn));

            % Expected result
            data = load(fullfile(rtt.toolFolder,"circles.mat"));
            expected = feval(fcn,data.circlesA,data.circlesB);

            % Build and deploy the MCP tool.
            ctf = prodserver.mcp.build(fcn,folder=test.tempFolder);
            endpoint = prodserver.mcp.deploy(ctf,test.host,test.port);

            % Call it.
            actual = prodserver.mcp.call(endpoint,fcn,data.circlesA,...
                data.circlesB);

            test.verifyEqual(actual,expected,"Circle intersections");
        end

        function byReference(test)
            % Test x-call-by: value
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            % Requires parameter-focused test tools
            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireParamTools());
            test.toolFolder = rtt.toolFolder;

            % Uses x-call-by: value in schema for the return value, which
            % otherwise would be externalized, as it contains 289 elements,
            % which is over the limit of MCPConstants.MaxLiteralSize.
            fcn = "callByReference";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,fcn));

            % Expected result
            data = load(fullfile(rtt.toolFolder,"circles.mat"));
            expected = feval(fcn,data.circlesA,data.circlesB);

            % Build and deploy the MCP tool.
            ctf = prodserver.mcp.build(fcn,folder=test.tempFolder);
            endpoint = prodserver.mcp.deploy(ctf,test.host,test.port);

            % Externalized data for the first argument.
            urlFolder = string(test.tempFolder);
            caURL = stow(test,urlFolder,"circlesA",data.circlesA);

            % Externalized data for the output
            tfURL = locate(test,"intersect",test.tempFolder);
            
            % Call it.
            prodserver.mcp.call(endpoint,fcn,caURL,...
                data.circlesB,tfURL=tfURL);

            actual = fetch(test, tfURL);

            test.verifyEqual(actual,expected,"Circle intersections");
        end
    end
end