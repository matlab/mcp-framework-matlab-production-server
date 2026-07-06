classdef tExternalCI < MCPCaller & ...
        prodserver.mcp.test.mixin.ExternalData 


    methods (TestClassSetup)

        function requireTools(test)
            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireParamTools());
            test.toolFolder = rtt.toolFolder;
        end
    end

    methods (TestMethodSetup)

        function tempSpace(test)
            % Temporary folder to contain wrappers
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture

            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            test.tempFolder = tFolder.Folder;
            test.applyFixture(PathFixture(test.tempFolder));

        end

    end

    methods (Test)

        function optionalAndExternal(test)
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            % Generate a wrapper for optInExtOut
            fcn = "optInExtOut";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,fcn));

            % Build tool
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder);
            test.verifyEqual(exist(ctf,"file"),2,ctf);

            % Deploy
            endpoint = prodserver.mcp.deploy(ctf,test.host,test.port);

            % Validate
            tf = prodserver.mcp.exist(endpoint,fcn,"Tool");
            test.verifyTrue(tf,fcn + " is not a tool at " + endpoint);

            % Call the original function to get the expected values.

            q = "a"; v = 1:17;
            p = struct('r', num2cell(1:10)', 'theta', num2cell(21:30)');
            t.r = 7; t.theta = 27;
            [z,u,m] = feval(fcn,q,v,p=p,t=t);
            test.verifyEqual(z,q+v);
            test.verifyEqual(u,sum(strlength(q+v)));
            test.verifyEqual(m,t);
            
            % Now call the deployed function using externalized inputs and
            % outputs.
            urlFolder = string(test.tempFolder);
            zURL = locate(test,"Z",urlFolder);
            mURL = locate(test,"M",urlFolder);

            % Externalize input data
            pURL = stow(test,urlFolder,"P",p);
            tURL = stow(test,urlFolder,"T",t);

            % Mix the order of the optional outputs all around.
            au = prodserver.mcp.call(endpoint,fcn,q,v,zURL=zURL,pURL=pURL,...
                mURL=mURL,tURL=tURL);

            az = fetch(test,zURL);
            am = fetch(test,mURL);

            test.verifyEqual(az,z,"Z not equal");
            test.verifyEqual(am,m,"M not equal");
            test.verifyEqual(au,u,"U not equal");

        end
    end
end