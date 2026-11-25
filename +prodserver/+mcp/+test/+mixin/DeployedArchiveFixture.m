classdef DeployedArchiveFixture < matlab.unittest.fixtures.Fixture
%DeployedArchiveFixture Act as code running in a deployed archive.
%
%     deployed = test.applyFixture( ...
%         prodserver.mcp.test.mixin.DeployedArchiveFixture("a_1"));
%     deployed.deployAs("b_2");      % another archive's copy
%     deployed.calls()                % deployedArchiveLocation's calls
%
%   A stand-in deployedArchiveLocation, earlier on the path, reports the
%   folder <archive>_<n> and no instance root, and counts its calls.
%   archiveCache is cleared when the fixture is set up, at each deployAs
%   and at teardown, so each starts with an empty cache, as a new archive
%   copy does on MPS: anything kept in archiveCache, the archive's Log
%   included, is made again. clear needs the short name: the
%   package-qualified one leaves a package function's persistent
%   variables in place (measured).

% Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = immutable)
        FolderName (1,1) string     % the folder the fixture starts in
    end

    properties (Constant, Access = private)
        Key = "prodserverMcpTestDeployedArchive"
    end

    methods
        function fix = DeployedArchiveFixture(folderName)
            arguments
                folderName (1,1) string
            end
            fix.FolderName = folderName;
            fix.SetupDescription = "Act as the deployed archive folder " + folderName + ".";
            fix.TeardownDescription = "Restore deployedArchiveLocation and clear archiveCache.";
        end

        function setup(fix)
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture
            root = string(fix.applyFixture(TemporaryFolderFixture).Folder);
            folder = fullfile(root, "+prodserver", "+mcp", "+handler");
            mkdir(folder);
            fid = fopen(fullfile(folder, "deployedArchiveLocation.m"), "w");
            fprintf(fid, "%s\n", ...
                "function loc = deployedArchiveLocation(varargin)", ...
                "    s = getappdata(0, """ + fix.Key + """);", ...
                "    s.calls = s.calls + 1;", ...
                "    setappdata(0, """ + fix.Key + """, s);", ...
                "    loc = struct('instanceRoot', """", 'folderName', s.folderName, ...", ...
                "        'archiveName', prodserver.mcp.handler.internal.archiveNameOf(s.folderName));", ...
                "end");
            fclose(fid);
            fix.addTeardown(@() rmappdata(0, fix.Key));
            fix.addTeardown(@() clear("archiveCache"));
            fix.applyFixture(PathFixture(root));
            rehash
            fix.deployAs(fix.FolderName);
        end

        function deployAs(fix, folderName)
        %deployAs Act as the archive copy in FOLDERNAME, with an empty archiveCache.
            arguments
                fix
                folderName (1,1) string
            end
            setappdata(0, fix.Key, struct("folderName", folderName, "calls", 0));
            clear("archiveCache");
        end

        function n = calls(fix)
        %calls How often deployedArchiveLocation was called since the last deployAs.
            s = getappdata(0, fix.Key);
            n = s.calls;
        end
    end

    methods (Access = protected)
        function tf = isCompatible(fx1, fx2)
            tf = fx1.FolderName == fx2.FolderName;
        end
    end
end
