classdef tWrapperCI < prodserver.mcp.test.base.MCPCaller

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

    methods (Test)
        function multiNone(test)

            fcn = ["toyScalarOne", "toyScalarTwo", "toyScalarFour"];
            wrapper = ["None", "None", "None"];
            archive = "wrapperCI";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,archive));

            % Build multi-tool application with no wrappers.
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                wrapper=wrapper,archive=archive);

            % Deploy using the full server URL (includes dynamic port)
            endpoint = prodserver.mcp.deploy(ctf,test.server);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                % Validate
                for n = 1:numel(fcn)
                    tf = prodserver.mcp.exist(endpoint,fcn(n),"Tool", ...
                        delay=10,retry=5,protocol=p);
                    test.verifyTrue(tf,fcn(n) + " not a tool [" + p + "]");
                end

                % One
                x = 983;
                eY = toyScalarOne(x);
                aY = prodserver.mcp.call(endpoint,"toyScalarOne",x);
                test.verifyEqual(aY,eY,"toyScalarOne [" + p + "]");

                % Two - non-deterministic
                s = "if we are to have in the universe an average density " + ...
                    "of matter which differs from zero, however small may be " + ...
                    "that difference, then the universe cannot be " + ...
                    "quasi-euclidean.";
                n = 9;
                [cs,d] = prodserver.mcp.call(endpoint,"toyScalarTwo",s,n);

                cap = isstrprop(cs,"upper");
                test.verifyTrue(nnz(cap) <= n, ...
                    "Count of capital letters [" + p + "]");
                pos = find(cap);
                test.verifyEqual(d,max(pos)-min(pos),"[" + p + "]");

                % Four - deterministic random number
                a = 17; c = 11; m = 27; x0 = 72;
                eX = toyScalarFour(a,c,m,x0);
                aX = prodserver.mcp.call(endpoint,"toyScalarFour",a,c,m,x0);
                test.verifyEqual(aX,eX,"toyScalarFour [" + p + "]");
            end

        end
    end
end
