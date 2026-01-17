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

            fcn = "toyToolOne";

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
            test.verifyTrue(tf,fcn + " is not a tool at " + endpoint)

            % Create the file URL inputs in the temporary folder.
            xURL = locate(test,"x",test.tempFolder);
            yURL = locate(test,"y",test.tempFolder);
            zURL = locate(test,"z",test.tempFolder);
            bURL = stow(test,test.tempFolder,"b",b);

            % Invoke - x,y,z and b are externalized.
            prodserver.mcp.call(endpoint,fcn,a,bURL,xURL,yURL,zURL);
            
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