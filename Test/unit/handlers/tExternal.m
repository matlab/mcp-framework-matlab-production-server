classdef tExternal < MCPHandlerBase & ...
        prodserver.mcp.test.mixin.ExternalData

% Call the mcpHandler to invoke a function that has externalized parameters.

% Copyright 2025-2026 The MathWorks, Inc.

    properties
        toolFolder
    end

    methods(Test)

        function externalOutputs(test)
            import prodserver.mcp.internal.hasField
            import matlab.unittest.fixtures.PathFixture

            % Generate definitions required by the mcpHandler
            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.toolFolder = rtt.toolFolder;

            % Wrapper folder must be on the path so we can call the
            % wrapper.
            test.applyFixture(PathFixture(test.tempFolder));

            % Generate wrapper for a function that uses a client-written
            % schema.
            fcn = "toyFileSchema";

            % Vanilla argument list. Generate wrappers and tool definition
            % but not archive.
            prodserver.mcp.build(fcn,folder=test.tempFolder,stop="Definition");

            % Get the expected value
            m = 11; r.x = 3; r.y = 4; r.z = 5;
            [eZ,eQ] = feval(fcn,m,r);

            % Allocate space for the triangle input and output
            rURL = stow(test,test.tempFolder,"R",r);
            aZURI = sink(test,"Z",test.tempFolder);

            % Call the function on the server.
            request = createRequest(test,fcn,test.server, ...
                "m", m, "rURL", rURL, "zURL", aZURI);
            response = prodserver.mcp.internal.mcpHandler(request);
            response = prodserver.mcp.internal.decodeBody(response);

            if hasField(response,"error")
                test.verifyFalse(true,response.error.message);
            end
            test.verifyTrue(hasField(response,"result"),"No result field");
            test.verifyTrue(hasField(response.result,"structuredContent.q"), ...
                "Missing output argument 'q'.");
            aQ = response.result.structuredContent.q;
            test.verifyEqual(aQ,eQ,"q");

            test.verifyEqual(string(response.result.structuredContent.zURL), ...
                aZURI,"Output location");
            test.verifyTrue(any(contains(response.result.content.text,aZURI)), ...
                "Content missing output URL");

            aZ = fetch(test,aZURI);
            test.verifyEqual(aZ,eZ,"Z");
        end
    end
end