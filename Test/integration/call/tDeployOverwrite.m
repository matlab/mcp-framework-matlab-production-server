classdef tDeployOverwrite < prodserver.mcp.test.base.MCPCaller
% Overwriting a deployed archive with a different build. The server goes on
% answering with the old archive for several seconds after the upload
% returns, so deploy used to return while the old tool still answered and
% the new one was "Found 0 tools". deploy now waits for the build it
% uploaded, which ping names.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Archive = "deployOverwrite"
    end

    methods (TestMethodSetup)
        function scratchSpace(test)
            tfolder = matlab.unittest.fixtures.TemporaryFolderFixture;
            applyFixture(test,tfolder);
            setFolders(test,temp=tfolder.Folder);
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive( ...
                test.server, test.Archive));
        end
    end

    methods (Test)

        function newToolIsLiveWhenDeployReturns(test)
            ctfOld = prodserver.mcp.build("toyScalarOne", archive=test.Archive, ...
                folder=fullfile(test.tempFolder, "old"), wrapper="None");
            ctfNew = prodserver.mcp.build("toyScalarTwo", archive=test.Archive, ...
                folder=fullfile(test.tempFolder, "new"), wrapper="None");
            uuid = prodserver.mcp.internal.archiveUUID(ctfNew);
            test.assertNotEqual(uuid, prodserver.mcp.internal.archiveUUID(ctfOld), ...
                "Two builds must have two UUIDs");

            prodserver.mcp.deploy(ctfOld, test.server);
            endpoint = prodserver.mcp.deploy(ctfNew, test.server);

            % At once: no waiting, no retrying.
            request = matlab.net.http.RequestMessage( ...
                matlab.net.http.RequestMethod.GET);
            response = request.send( ...
                matlab.net.URI(replace(endpoint, "/mcp", "/ping")));
            field = response.getFields( ...
                prodserver.mcp.internal.Constants.ArchiveUUIDHeader);
            test.assertNotEmpty(field, "ping must name the build answering");
            test.verifyEqual(string(field(1).Value), uuid);

            tools = prodserver.mcp.list(endpoint, "Tool", retry=1, delay=1);
            names = cellfun(@(t) string(t.name), tools);
            test.verifyTrue(ismember("toyScalarTwo", names), ...
                "The new tool: " + strjoin(names, ", "));
            test.verifyFalse(ismember("toyScalarOne", names), ...
                "The old tool: " + strjoin(names, ", "));

            s = "Abc def";
            [cs, d] = prodserver.mcp.call(endpoint, "toyScalarTwo", s, 2);
            test.verifyNotEmpty(cs);
            test.verifyNotEmpty(d);
        end

    end

end
