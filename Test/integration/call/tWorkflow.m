classdef tWorkflow < MCPCaller & ...
        prodserver.mcp.test.mixin.ExternalData

% Copyright 2026-2026 The MathWorks, Inc.

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
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive);
            test.verifyEqual(exist(ctf,"file"),2,ctf);

            % Deploy
            endpoint = prodserver.mcp.deploy(ctf,test.host,test.port);

            % Validate
            tf = prodserver.mcp.exist(endpoint,fcn,"Tool");
            test.verifyTrue(tf,fcn + " is not a tool at " + endpoint);

            % Read the default resource
            resource = prodserver.mcp.list(endpoint,"Resource");
            test.verifyFalse(isempty(resource),"No resources!");
            test.verifyEqual(numel(resource),1,"Wrong number of resources");
            test.verifyTrue(iscell(resource),"Not a cell array");
            resource = resource{1};
            test.verifyTrue(isstruct(resource),"Not a structure");
            rName = [resource.name];
            encoding_rules = prodserver.mcp.read(endpoint,rName);
            test.verifyEqual(numel(encoding_rules),1,"Number of encoding documents");
            resourceTextFile = fullfile(fileparts(mfilename("fullpath")),...
                "..","..","..", "+prodserver","+mcp","+jsonrpc",...
                "wire_encoding_rules.txt");
            resourceText = string(fileread(resourceTextFile));
            test.verifyEqual(encoding_rules,resourceText);

            % Use the built-in resource-reading tool to read the resource.
            % (Ensures the tool was packaged with the vanilla server.)
            encoding_rules_resource = prodserver.mcp.call(endpoint,...
                prodserver.mcp.MCPConstants.ReadResourceTool, ...
                prodserver.mcp.MCPConstants.WireEncodingResourceURI);

            test.verifyTrue(prodserver.mcp.internal.hasField(...
                encoding_rules_resource,"mimeType"));
            test.verifyTrue(prodserver.mcp.jsonrpc.isMIMETypeText(...
                encoding_rules_resource.mimeType),"MIME type");

            test.verifyTrue(prodserver.mcp.internal.hasField(...
                encoding_rules_resource,"text"), "text field");
            test.verifyEqual(encoding_rules_resource.text, char(resourceText), ...
                "MCP resource reading tool");

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