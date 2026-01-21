classdef tWrapperCI < MCPCaller

    methods (TestMethodSetup)
        function scratchSpace(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            % Temporary folder for intermediate / generated artifacts
            tfolder = TemporaryFolderFixture;
            applyFixture(test,tfolder);
            test.tempFolder = tfolder.Folder;
        end
    end

    methods (Test)
        function multiNone(test)

            fcn = ["toyScalarOne", "toyScalarTwo", "toyScalarFour"];
            wrapper = ["None", "None", "None"];
            
            % Build multi-tool application with no wrappers.
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                wrapper=wrapper);

            % % Deploy
            endpoint = prodserver.mcp.deploy(ctf,test.host,test.port);

            % Validate
            for n = 1:numel(fcn)
                tf = prodserver.mcp.exist(endpoint,fcn(n),"Tool");
                test.verifyTrue(tf,fcn(n) + " is not a tool at " + endpoint);
            end

            %
            % Call each tool
            %

            % One
            x = 983;
            eY = toyScalarOne(x);
            aY = prodserver.mcp.call(endpoint,"toyScalarOne",x);
            test.verifyEqual(aY,eY,"toyScalarOne");

            % Two - non-deterministic
            s = "if we are to have in the universe an average density " + ...
                "of matter which differs from zero, however small may be " + ...
                "that difference, then the universe cannot be " + ...
                "quasi-euclidean.";
            n = 9;
            [cs,d] = prodserver.mcp.call(endpoint,"toyScalarTwo",s,n);

            cap = isstrprop(cs,"upper");
            test.verifyTrue(nnz(cap) <= n, "Count of capital letters");
            pos = find(cap);
            test.verifyEqual(d,max(pos)-min(pos));

            % Four - deterministic random number
            a = 17; c = 11; m = 27; x0 = 72;
            eX = toyScalarFour(a,c,m,x0);
            aX = prodserver.mcp.call(endpoint,"toyScalarFour",a,c,m,x0);
            test.verifyEqual(aX,eX,"toyScalarFour");

        end
    end
end