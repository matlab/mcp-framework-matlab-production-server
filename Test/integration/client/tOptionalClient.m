classdef tOptionalClient < MockCaller

    properties
        toolFolder
    end

    methods(TestClassSetup)
        function initTest(test)
            testFolder = fileparts(mfilename("fullpath"));
            test.toolFolder = fullfile(testFolder,"..","..","tools", ...
                "toyTools");
        end
    end

    methods(Test)

        function scalarOptions(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            import prodserver.mcp.MCPConstants

            tempFolder = TemporaryFolderFixture;
            applyFixture(test,tempFolder);
            tfolder = tempFolder.Folder;

            fcn = "toyScalarOptions";

            % Add the tools folder to the path.
            test.applyFixture(PathFixture(test.toolFolder));

            % Generate wrappers and build -- only generate wrapper and
            % definition. Don't build the archive, because that takes a long
            % time.
            prodserver.mcp.build(fcn, folder=tfolder, stop="Definition");

            % Add the temporary folder to the path.
            test.applyFixture(PathFixture(tfolder));

            % year, mpg, range, make, model
            args = { 1999,1001,100000,"Polaris","Zeta" };

            % Start the mock server with configuration for this test point
            endpoint = startMcpServer(test,"tOptionalScalarOptions.yaml");

            for n = numel(args):-1:1
                % Call original for expected value
                expected = feval(fcn,args{1:n});
    
                % Call the function on the mock server.
                actual = prodserver.mcp.call(endpoint,fcn,args{1:n});
    
                test.verifyEqual(actual,expected,sprintf("Max arg #%d",n));
            end 
        end
    end

end