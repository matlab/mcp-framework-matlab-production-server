classdef tArchiveIsolation < matlab.unittest.TestCase
% archiveCache on a real MPS instance: two archives in one worker keep
% separate entries, and a hot redeploy starts empty. A third test records
% the platform fact that removed archiveCache's worker scope: appdata(0)
% is not shared between the archives in a worker.
%
% Needs MW_MCP_MPS_TEST_SERVER naming an instance with ONE worker, so every
% call reaches the same process. On an instance with more, the tests are
% skipped: class setup probes the server and assumes one process answered,
% and each test assumes its own calls did, since MPS may move a later
% request to another worker.
% fndA and fndB are removed from the server before and after the class.

% Copyright 2026 The MathWorks, Inc.

    properties
        Server (1,1) string = ""
        CtfA (1,1) string = ""
    end

    methods (TestClassSetup)
        function deployProbes(test)
            test.Server = string(getenv("MW_MCP_MPS_TEST_SERVER"));
            test.assumeNotEmpty(char(test.Server), "MW_MCP_MPS_TEST_SERVER is not set.");
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(test.Server, ["fndA", "fndB"]));
            out = string(test.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            here = fileparts(mfilename("fullpath"));
            for archive = ["fndA", "fndB"]
                folder = fullfile(out, archive);
                compiler.build.productionServerArchive(fullfile(here, "fndProbe.m"), ...
                    ArchiveName=archive, OutputDir=folder, Verbose="off");
                ctf = fullfile(folder, archive + ".ctf");
                if archive == "fndA"
                    test.CtfA = ctf;
                end
                deployAndWait(test, ctf, archive);
            end
            % Ten calls, one process: the instance has one worker, or these
            % tests can't tell archive isolation from worker isolation.
            pids = zeros(1, 10);
            for k = 1:numel(pids)
                pids(k) = probe(test, "fndA", "get").pid;
            end
            test.assumeEqual(numel(unique(pids)), 1, ...
                "These tests need an instance with one worker; this one answered from " + ...
                numel(unique(pids)) + " processes.");
        end
    end

    methods (Test)

        function twoArchivesInOneWorkerSeeOnlyTheirOwnEntries(test)
            a = probe(test, "fndA", "set", "from A");
            b = probe(test, "fndB", "get");
            test.verifyEqual(b.value, "<none>", "B does not see A's entry");
            probe(test, "fndB", "set", "from B");
            a2 = probe(test, "fndA", "get");
            b2 = probe(test, "fndB", "get");
            test.verifyEqual(a2.value, "from A");
            test.verifyEqual(b2.value, "from B");
            pids = [a.pid b.pid a2.pid b2.pid];
            test.assumeEqual(unique(pids), pids(1), "every call reached one worker");
            test.verifyNotEqual(a.folder, b.folder);
        end

        function aHotRedeployServesTheNewDefinitions(test)
            before = probe(test, "fndA", "set", "old deploy");
            deployAndWait(test, test.CtfA, "fndA", before.folder);
            after = probe(test, "fndA", "get");
            test.verifyNotEqual(after.folder, before.folder, "a new <archive>_<n>");
            test.verifyEqual(after.value, "<none>", "the new deploy starts empty");
            test.assumeEqual(after.pid, before.pid, "in the same worker");
        end
    end

    methods (Test)
        function appdataIsNotSharedBetweenArchives(test)
            % The platform fact behind removing the worker scope: in one
            % worker, B does not see what A put in appdata(0).
            a = probe(test, "fndA", "setAppdata", "from A");
            b = probe(test, "fndB", "getAppdata");
            test.assumeEqual(b.pid, a.pid, "both calls reached one worker");
            test.verifyEqual(b.value, "<none>");
            test.verifyEqual(probe(test, "fndA", "getAppdata").value, "from A", ...
                "A still sees its own");
        end
    end

    methods (Access = private)
        function out = probe(test, archive, op, value)
            arguments
                test
                archive (1,1) string
                op (1,1) string
                value (1,1) string = ""
            end
            body = struct("nargout", 1, "rhs", {{char(op), char(value)}}, ...
                "outputFormat", struct("mode", "small"));
            opts = weboptions(MediaType="application/json", Timeout=60);
            r = webwrite(test.Server + "/" + archive + "/fndProbe", body, opts);
            lhs = r.lhs;
            if iscell(lhs), lhs = lhs{1}; end
            out = struct("value", string(lhs.value), "folder", string(lhs.folder), ...
                "pid", double(lhs.pid));
        end

        function deployAndWait(test, ctf, archive, oldFolder)
            % Upload, then wait until the archive answers, from a new folder
            % when OLDFOLDER is given.
            arguments
                test
                ctf (1,1) string
                archive (1,1) string
                oldFolder (1,1) string = ""
            end
            prodserver.mcp.deploy(ctf, test.Server, verify=false);
            for k = 1:90
                try
                    out = probe(test, archive, "get");
                    if out.folder ~= oldFolder
                        return
                    end
                catch
                end
                pause(2);
            end
            test.assertFail(archive + " did not answer after the upload.");
        end
    end
end
