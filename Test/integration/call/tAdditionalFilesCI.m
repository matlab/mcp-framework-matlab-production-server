classdef tAdditionalFilesCI < MCPCaller & ...
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

        function threeTools(test)
        % Three tools and lots of data files.

            fcn = ["toyScalarOne", "toySummary", "toyToolOne"];
            archiveName = "tripleToolTechnology";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,archiveName));

            % Create data files for toySummary
            N = 13;
            baseName = "dataFile";
            dataFile = strings(1,N);
            dataName = dataFile;
            for k = 1:N
                dataName(k) = baseName+string(k)+".mat";
                dataFile(k) = fullfile(test.tempFolder,dataName(k));
                content = randi(1024,1);
                save(dataFile(k),"content");
            end

            % Expected results
            ten = 10;
            eleven = toyScalarOne(ten);

            eSummary = toySummary(dataFile);

            a = 3; b = 17;
            [eX,eY,eZ] = toyToolOne(a,b);

            % Build tool
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                files=dataFile,archive=archiveName);
            test.verifyEqual(exist(ctf,"file"),2,ctf);

            % Deploy -- port is allowed to be empty.
            port = {};
            if ~isempty(port), port = { test.port }; end
            endpoint = prodserver.mcp.deploy(ctf,test.host,port{:});

            for k=1:numel(fcn)
                tf = prodserver.mcp.exist(endpoint,fcn(k),"Tool",delay=10,retry=5);
                test.verifyTrue(tf,fcn(k) + " is not a tool at " + endpoint);
            end

            % Call the tools

            % 
            % toyScalarOne
            %
            actualEleven = prodserver.mcp.call(endpoint,fcn(1),ten);
            test.verifyEqual(actualEleven,eleven);

            % 
            % toySummary
            %

            dataURL = stow(test,test.dataFolder,"data",dataFile);
            summaryURL = locate(test,"summary",test.dataFolder);
            prodserver.mcp.call(endpoint,fcn(2),dataURL,summaryURL);
            aSummary= fetch(test,summaryURL);
            test.verifyEqual(aSummary,eSummary);

            %
            % toyToolOne
            %

            % Create the file URL inputs in the temporary folder.
            xURL = locate(test,"x",test.dataFolder);
            yURL = locate(test,"y",test.dataFolder);
            zURL = locate(test,"z",test.dataFolder);
            bURL = stow(test,test.dataFolder,"b",b);

            % Invoke - x,y,z and b are externalized.
            prodserver.mcp.call(endpoint,fcn(3),a,bURL,xURL,yURL,zURL);

            % Fetch outputs from their URLs.
            aX = fetch(test,xURL);
            aY = fetch(test,yURL);
            aZ = fetch(test,zURL);

            test.verifyEqual(aX,eX);
            test.verifyEqual(aY,eY);
            test.verifyEqual(aZ,eZ);

        end
    end
end