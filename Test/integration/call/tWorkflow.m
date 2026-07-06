classdef tWorkflow < MCPCaller & ...
        prodserver.mcp.test.mixin.ExternalData


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

        function vanilla(test)
        % Main line, ordinary workflow. Deploy and call a simple tool. 
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            fcn = "toyToolOne";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,fcn));

            % Expected result
            a = 3; b = 17;
            [eX,eY,eZ] = feval(fcn,a,b);

            % Build tool
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder);
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
                MCPConstants.ReadResourceTool,MCPConstants.WireEncodingResourceURI);

            test.verifyTrue(hasField(encoding_rules_resource,"mimeType"));
            test.verifyTrue(prodserver.mcp.jsonrpc.isMIMETypeText(...
                encoding_rules_resource.mimeType),"MIME type");

            test.verifyTrue(hasField(encoding_rules_resource,"text"), ...
                "text field");
            test.verifyEqual(encoding_rules_resource.text, char(resourceText), ...
                "MCP resource reading tool");

            % Create the file URL inputs in the temporary folder.
            xURL = locate(test,"x",test.tempFolder);
            yURL = locate(test,"y",test.tempFolder);
            zURL = locate(test,"z",test.tempFolder);
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
        end
    end
end