classdef tWorkflow < MCPCaller & ...
        prodserver.mcp.test.mixin.ExternalData

% Copyright 2026 The MathWorks, Inc.

    methods (TestMethodSetup)
        function scratchSpace(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            % Temporary folder for intermediate / generated artifacts
            tfolder = TemporaryFolderFixture;
            applyFixture(test,tfolder);
            setFolders(test,temp=tfolder.Folder);
        end
    end

    methods(Test)

        function vanilla(test)
        % Main line, ordinary workflow. Deploy and call a simple tool.

            fcn = "toyToolOne";
            archive = "worflow";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,archive));

            % Expected result
            a = 3; b = 17;
            [eX,eY,eZ] = feval(fcn,a,b);

            % Build tool
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder,...
                archive=archive);
            test.verifyEqual(exist(ctf,"file"),2,ctf);

            % Deploy using the full server URL (includes dynamic port)
            endpoint = prodserver.mcp.deploy(ctf,test.server);

            % Validate
            tf = prodserver.mcp.exist(endpoint,fcn,"Tool",delay=10,retry=5);
            test.verifyTrue(tf,fcn + " is not a tool at " + endpoint)

            % Create the file URL inputs in the temporary folder.
            xURL = locate(test,"x",test.dataFolder);
            yURL = locate(test,"y",test.dataFolder);
            zURL = locate(test,"z",test.dataFolder);
            bURL = stow(test,test.dataFolder,"b",b);

            % Invoke - x,y,z and b are externalized.
            prodserver.mcp.call(endpoint,fcn,a,bURL,xURL,yURL,zURL);
            
            % Fetch outputs from their URLs.
            aX = fetch(test,xURL);
            aY = fetch(test,yURL);
            aZ = fetch(test,zURL);

            test.verifyEqual(aX,eX,"x");
            test.verifyEqual(aY,eY,"y");
            test.verifyEqual(aZ,eZ,"z");

            % Validate metrics
            serverMetrics = prodserver.mcp.MCPConstants.MCPMetricPrefix + ...
                archive + prodserver.mcp.MCPConstants.MCPMetricSuffix;
            metrics = prodserver.mcp.metrics(endpoint,...
                prodserver.mcp.MetricsScope.MCP);

            % Non-zero server request count
            test.verifyGreaterThan(metrics.(serverMetrics).value,0);

            % Server request count less than or equal to framework request
            % count.
            test.verifyTrue(metrics.(serverMetrics).value <= ...
                metrics.(prodserver.mcp.MCPConstants.MCPRequestMetric).value, ...
                "Server metric > Request metric");

            % Tools call count exactly equal to 1
            toolCallMetric = prodserver.mcp.MCPConstants.MCPMetricPrefix + ...
                fcn + prodserver.mcp.MCPConstants.MCPToolCallSuffix;
            test.verifyEqual(metrics.(toolCallMetric).value, 1);


        end

    end
end