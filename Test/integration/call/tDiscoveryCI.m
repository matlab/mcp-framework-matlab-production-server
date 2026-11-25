classdef tDiscoveryCI < prodserver.mcp.test.base.MCPCaller

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

            % From R2027a every archive is listed, mcpHandler included, so
            % the listing alone doesn't show the signatures file arrived.
            % Its help does: it names the MCP revisions the server speaks.
            help = discoveryHelp(response, archive);
            test.verifyTrue(any(contains(help, "MCP-Versions:")), ...
                "mcpHandler's discovery help should name the MCP " + ...
                "revisions. Help found: " + strjoin(help, " | "));
        end

        function discoveryDisabledArchiveHasNoFrameworkMetadata(test)
        % A deployed archive built with discovery=false carries none of the
        % framework's discovery metadata.
        %
        % Whether it's listed at all is the server's business. Up to
        % R2026b, MPS lists only an archive that has function signatures,
        % so this one isn't. From R2027a discovery is on for every
        % archive: MPS lists this one, with a stand-in entry for each
        % exported function that has its argument names but empty help,
        % types and sizes. Neither has the MCP-Versions: help of the
        % signatures file build writes when discovery=true.

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

            response = webread(test.server + "/api/discovery");
            help = discoveryHelp(response, archive);
            test.verifyFalse(any(contains(help, "MCP-Versions:")), ...
                "Archive built with discovery=false should have no " + ...
                "framework metadata. Help found: " + strjoin(help, " | "));
        end

    end
end

function help = discoveryHelp(response, archive)
% The help text of every function signature /api/discovery lists for
% ARCHIVE: string.empty if the archive isn't listed. jsondecode makes the
% signatures of a function a struct, a struct array or a cell array,
% depending on how many there are and whether their fields agree.
    help = string.empty;
    if ~isfield(response, "archives") || ~isfield(response.archives, archive) ...
            || ~isfield(response.archives.(archive), "functions")
        return
    end
    fcns = response.archives.(archive).functions;
    for f = string(fieldnames(fcns))'
        if ~isfield(fcns.(f), "signatures")
            continue
        end
        sigs = fcns.(f).signatures;
        if isstruct(sigs)
            sigs = num2cell(sigs);
        end
        for s = sigs(:)'
            % Appended, not assigned to help(end+1): "help": null decodes
            % as [], and string([]) is empty, which can't fill one element.
            if isfield(s{1}, "help")
                h = string(s{1}.help);
                help = [help, h(:)']; %#ok<AGROW>
            end
        end
    end
end
