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
            archive = "workflow";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,archive));

            % Expected result
            a = 3; b = 17;
            [eX,eY,eZ] = feval(fcn,a,b);

            % Build tool
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive);
            test.verifyEqual(exist(ctf,"file"),2,ctf);

            % Deploy
            endpoint = prodserver.mcp.deploy(ctf,test.host,test.port);

            % Validate
            tf = prodserver.mcp.exist(endpoint,fcn,"Tool");
            test.verifyTrue(tf,fcn + " is not a tool at " + endpoint);

            % Create the file URL inputs in the temporary folder.
            xURL = sink(test,"x",test.tempFolder);
            yURL = sink(test,"y",test.tempFolder);
            zURL = sink(test,"z",test.tempFolder);
            bURL = stow(test,test.tempFolder,"b",b);

            % Invoke - x,y,z and b are externalized.
            prodserver.mcp.call(endpoint,fcn,a,bURL,xURL=xURL,...
                yURL=yURL,zURL=zURL);
            
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
            catalog = prodserver.mcp.metrics(endpoint);

            % Non-zero server request count
            sm = name(catalog,serverMetrics);
            test.verifyGreaterThan(sum([sm.value]),0);

            % Server request count less than or equal to framework request
            % count.
            frm = name(catalog,prodserver.mcp.MCPConstants.MCPRequestMetric);
            test.verifyTrue(sum([sm.value]) <= sum([frm.value]), ...
                "Server metric > Request metric");

            % Tools call count exactly equal to 1 -- may be multiple
            % metrics from older versions of this archive. All the values
            % should be 1.
            toolCallMetric = prodserver.mcp.MCPConstants.MCPMetricPrefix + ...
                fcn + prodserver.mcp.MCPConstants.MCPToolCallSuffix;
            tcm = name(catalog,toolCallMetric);
            for n=1:numel(tcm)
                test.verifyEqual(tcm(n).value, 1,tcm(n).archive+tcm(n).suffix);
            end

        end

    end
end