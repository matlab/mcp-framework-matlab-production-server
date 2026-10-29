classdef tOptionalCI < prodserver.mcp.test.base.MCPCaller

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

        function scalarNVP(test)
            import prodserver.mcp.MCPConstants

            % Many optional arguments
            fcn = "toyScalarNVOptions";
            archive = "optionalCINVP";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,archive));

            % Build
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder,...
                archive=archive);
            test.verifyEqual(exist(ctf,"file"),2,ctf);

            % Deploy using the full server URL (includes dynamic port)
            endpoint = prodserver.mcp.deploy(ctf,test.server);

            % year, mpg, range, make, model
            year = 1999;
            values = { 1001,100000,"Polaris","Zeta" };
            names = { 'mpg', 'range', 'make', 'model'};
            args = [ names ; values ];
            args = { year, args{:} };

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                % Validate
                tf = prodserver.mcp.exist(endpoint,fcn,"Tool", ...
                    delay=10,retry=5,protocol=p);
                test.verifyTrue(tf,fcn + " not a tool [" + p + "]")

                % Start by calling with all arguments, then drop them,
                % one-by-one.
                for n = numel(args):-2:1
                    expected = feval(fcn,args{1:n});
                    actual = prodserver.mcp.call(endpoint,fcn,args{1:n});
                    test.verifyEqual(actual,char(expected), ...
                        sprintf("Max arg #%d [%s]",n,p));
                end
            end
        end

        function scalarOptions(test)

            import prodserver.mcp.MCPConstants

            % Many optional arguments
            fcn = "toyScalarOptions";
            archive = "optionalCIOptions";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,archive));

            % Build
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive);
            test.verifyEqual(exist(ctf,"file"),2,ctf);

            % Deploy using the full server URL (includes dynamic port)
            endpoint = prodserver.mcp.deploy(ctf,test.server);

            % year, mpg, range, make, model
            args = { 1999,1001,100000,"Polaris","Zeta" };

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                % Validate
                tf = prodserver.mcp.exist(endpoint,fcn,"Tool", ...
                    delay=10,retry=5,protocol=p);
                test.verifyTrue(tf,fcn + " not a tool [" + p + "]")

                % Start by calling with all arguments, then drop them,
                % one-by-one.
                for n = numel(args):-1:1
                    expected = feval(fcn,args{1:n});
                    actual = prodserver.mcp.call(endpoint,fcn,args{1:n});
                    test.verifyEqual(actual,char(expected), ...
                        sprintf("Max arg #%d [%s]",n,p));
                end
            end
        end
    end

end
