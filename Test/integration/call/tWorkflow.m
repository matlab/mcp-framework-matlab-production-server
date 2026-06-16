classdef tWorkflow < MCPCaller & ...
        prodserver.mcp.test.mixin.ExternalData


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
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,fcn));

            % Expected result
            a = 3; b = 17;
            [eX,eY,eZ] = feval(fcn,a,b);

            % Build tool
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder);
            test.verifyEqual(exist(ctf,"file"),2,ctf);

            % Deploy -- port is allowed to be empty.
            port = {};
            if ~isempty(port), port = { test.port }; end
            endpoint = prodserver.mcp.deploy(ctf,test.host,port{:});

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
        end

    end
end