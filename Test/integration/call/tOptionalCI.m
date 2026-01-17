classdef tOptionalCI < MCPCaller

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

        function scalarNVP(test)
            import prodserver.mcp.MCPConstants

            % Many optional arguments
            fcn = "toyScalarNVOptions";

            % Build
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder);
            test.verifyEqual(exist(ctf,"file"),2,ctf);

            % Deploy
            endpoint = prodserver.mcp.deploy(ctf,test.host,test.port);

            % Validate
            tf = prodserver.mcp.exist(endpoint,fcn,"Tool");
            test.verifyTrue(tf,fcn + " is not a tool at " + endpoint)

            % year, mpg, range, make, model
            year = 1999;
            values = { 1001,100000,"Polaris","Zeta" };
            names = { 'mpg', 'range', 'make', 'model'};
            args = [ names ; values ];
            args = { year, args{:} };

            % Start by calling with all arguments, then drop them,
            % one-by-one.
            for n = numel(args):-2:1
                % Call original for expected value
                expected = feval(fcn,args{1:n});

                % Call the function on the server.
                actual = prodserver.mcp.call(endpoint,fcn,args{1:n});

                test.verifyEqual(actual,expected,sprintf("Max arg #%d",n));
            end 
        end

        function scalarOptions(test)
            import prodserver.mcp.MCPConstants

            % Many optional arguments
            fcn = "toyScalarOptions";

            % Build
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder);
            test.verifyEqual(exist(ctf,"file"),2,ctf);

            % Deploy
            endpoint = prodserver.mcp.deploy(ctf,test.host,test.port);

            % Validate
            tf = prodserver.mcp.exist(endpoint,fcn,"Tool");
            test.verifyTrue(tf,fcn + " is not a tool at " + endpoint)

            % year, mpg, range, make, model
            args = { 1999,1001,100000,"Polaris","Zeta" };

            % Start by calling with all arguments, then drop them,
            % one-by-one.
            for n = numel(args):-1:1
                % Call original for expected value
                expected = feval(fcn,args{1:n});
    
                % Call the function on the server.
                actual = prodserver.mcp.call(endpoint,fcn,args{1:n});
    
                test.verifyEqual(actual,expected,sprintf("Max arg #%d",n));
            end 
        end
    end

end