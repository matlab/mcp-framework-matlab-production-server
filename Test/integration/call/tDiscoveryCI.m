classdef tDiscoveryCI < MCPCaller

% Copyright 2026 The MathWorks, Inc.

    methods(TestClassSetup)

        function requireDiscovery(test)
        % Fail early if /api/discovery is not enabled on the test server.

            discoveryUrl = test.server + "/api/discovery";
            try
                response = webread(discoveryUrl);
            catch me
                test.assertFail("GET " + discoveryUrl + " failed: " + ...
                    me.message + ". Ensure --enable-discovery is set " + ...
                    "in main_config.");
            end

            test.assertTrue(isstruct(response), ...
                "/api/discovery did not return a valid JSON structure.");
            test.assertTrue(isfield(response, "discoverySchemaVersion"), ...
                "Response missing discoverySchemaVersion field");
        end

    end

    methods (TestMethodSetup)
        function scratchSpace(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tfolder = TemporaryFolderFixture;
            applyFixture(test, tfolder);
            setFolders(test, temp=tfolder.Folder);
        end
    end

    methods(Test)

        function deployedArchiveDiscoverable(test)
        % A deployed archive built with discovery=true appears in /api/discovery.

            import prodserver.mcp.MCPConstants

            fcn = "toyToolOne";
            archive = "discoveryIT";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, discovery=true);

            prodserver.mcp.deploy(ctf, test.host, test.port);

            discoveryUrl = test.server + "/api/discovery";
            response = webread(discoveryUrl);

            test.verifyTrue(isfield(response, "archives"), ...
                "Response missing archives field");
            test.verifyTrue(isfield(response.archives, archive), ...
                "Deployed archive '" + archive + "' not in discovery response");

            archiveInfo = response.archives.(archive);
            test.verifyTrue(isfield(archiveInfo, "functions"), ...
                "Archive info missing functions field");

            % The discovery endpoint may mangle dotted names. Check for
            % either the qualified or mangled form.
            fcnFields = fieldnames(archiveInfo.functions);
            hasMcpHandler = any(contains(fcnFields, "mcpHandler"));
            test.verifyTrue(hasMcpHandler, ...
                "mcpHandler not listed in discoverable functions");
        end

        function discoveryDisabledArchiveNotDiscoverable(test)
        % A deployed archive built with discovery=false has no function signatures.

            import prodserver.mcp.MCPConstants

            fcn = "toyToolOne";
            archive = "noDiscovIT";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, discovery=false);

            prodserver.mcp.deploy(ctf, test.host, test.port);

            % Verify the archive is deployed and responsive
            endpoint = test.server + "/" + archive + "/mcp";
            test.assertTrue(prodserver.mcp.ping(endpoint), ...
                "Archive should be deployed and responsive");

            discoveryUrl = test.server + "/api/discovery";
            response = webread(discoveryUrl);

            if isfield(response, "archives") && ...
                    isfield(response.archives, archive)
                archiveInfo = response.archives.(archive);
                if isfield(archiveInfo, "functions")
                    test.verifyTrue(isempty(fieldnames(archiveInfo.functions)), ...
                        "Archive built with discovery=false should have no function signatures");
                end
            end
        end

    end
end
