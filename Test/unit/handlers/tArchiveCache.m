classdef tArchiveCache < matlab.unittest.TestCase
% archiveCache and deployedArchiveLocation: one key rule for every worker
% cache, and a redeploy evicts the archive's earlier entries. ctfRoot=
% stands in for ctfroot, so each test acts as deploys of named archives
% without knowing how the key is built.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Name = "tArchiveCacheProbe"
    end

    methods (TestMethodSetup)
        function clean(test)
            test.addTeardown(@() prodserver.mcp.handler.archiveCache(test.Name, action="clearAll"));
            prodserver.mcp.handler.archiveCache(test.Name, action="clearAll");
        end
    end

    methods (Test)

        function locationSplitsTheArchiveFromItsVersion(test)
            import prodserver.mcp.handler.deployedArchiveLocation
            loc = deployedArchiveLocation(ctfRoot=fullfile(tempdir, "auto_deploy", "noise_12"));
            test.verifyEqual(loc.folderName, "noise_12");
            test.verifyEqual(loc.archiveName, "noise");
            loc = deployedArchiveLocation(ctfRoot=fullfile(tempdir, "R2026b") + filesep);
            test.verifyEqual(loc.folderName, "R2026b");
            test.verifyEqual(loc.archiveName, "", "no _<n> suffix: not deployed");
        end

        function getReturnsWhatSetStored(test)
            test.verifyEmpty(get(test, "noise_1"));
            set(test, "noise_1", 42);
            test.verifyEqual(get(test, "noise_1"), 42);
            prodserver.mcp.handler.archiveCache(test.Name, action="clear", ctfRoot=root("noise_1"));
            test.verifyEmpty(get(test, "noise_1"));
        end

        function setEvictsEarlierVersionsOfTheSameArchiveOnly(test)
            set(test, "noise_3", 3);
            set(test, "signal_3", 30);
            set(test, "noise_4", 4);
            test.verifyEmpty(get(test, "noise_3"), "the earlier deploy is evicted");
            test.verifyEqual(get(test, "noise_4"), 4);
            test.verifyEqual(get(test, "signal_3"), 30, "another archive is untouched");
        end

        function theFolderRuleNamesTheArchive(test)
            import prodserver.mcp.handler.internal.archiveNameOf
            test.verifyEqual(archiveNameOf(["noise_12", "a_b_3", "R2026b", "x_", "_4", "x_1a"]), ...
                ["noise", "a_b", "", "", "", ""]);
            test.verifyEqual(archiveNameOf(strings(0, 1)), strings(0, 1));
        end

        function namesThatDifferOnlyInAnInvalidCharacterNeverShare(test)
            set(test, "my-tools_1", 1);
            set(test, "my_tools_1", 2);
            test.verifyEqual(get(test, "my-tools_1"), 1);
            test.verifyEqual(get(test, "my_tools_1"), 2);
        end

        function longArchiveNamesKeepTheirVersions(test)
            name = string(repmat('a', 1, 60));
            set(test, name + "_1", 1);
            set(test, name + "_2", 2);
            test.verifyEmpty(get(test, name + "_1"), "version 1 is evicted");
            test.verifyEqual(get(test, name + "_2"), 2);
        end

        function clearAllLeavesANameThatExtendsIt(test)
            % "x" is a prefix of "x_y": clearing "x" must not clear "x_y".
            import prodserver.mcp.handler.archiveCache
            long = test.Name + "_y";
            test.addTeardown(@() archiveCache(long, action="clearAll"));
            set(test, "noise_1", "short");
            archiveCache(long, action="set", value="long", ctfRoot=root("noise_1"));
            archiveCache(test.Name, action="clearAll");
            test.verifyEmpty(get(test, "noise_1"));
            test.verifyEqual(archiveCache(long, ctfRoot=root("noise_1")), "long");
        end

        function evictionLeavesANameWhoseKeyLooksAlike(test)
            % NAME "x" in archive "a_b" and NAME "x_a" in archive "b" once
            % made the same key, x_a_b_<n>: neither may overwrite or evict
            % the other.
            import prodserver.mcp.handler.archiveCache
            other = test.Name + "_a";
            test.addTeardown(@() archiveCache(other, action="clearAll"));
            archiveCache(other, action="set", value="other", ctfRoot=root("b_1"));
            archiveCache(test.Name, action="set", value="mine", ctfRoot=root("a_b_1"));
            archiveCache(test.Name, action="set", value="mine 2", ctfRoot=root("a_b_2"));
            test.verifyEqual(archiveCache(other, ctfRoot=root("b_1")), "other");
            test.verifyEmpty(archiveCache(test.Name, ctfRoot=root("a_b_1")), "its own old version goes");
        end

        function clearAllRemovesEveryVersion(test)
            set(test, "noise_1", 1);
            set(test, "signal_4", 2);
            prodserver.mcp.handler.archiveCache(test.Name, action="clearAll");
            test.verifyEmpty(get(test, "noise_1"));
            test.verifyEmpty(get(test, "signal_4"));
        end

        function locationFindsTheInstanceRoot(test)
            import prodserver.mcp.handler.deployedArchiveLocation
            instance = string(test.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            mkdir(fullfile(instance, "config"));
            mkdir(fullfile(instance, "endpoint"));
            endpoint = fullfile(instance, "endpoint");
            loc = deployedArchiveLocation(endpointRoot=endpoint, ctfRoot=root("noise_1"));
            test.verifyEqual(loc.instanceRoot, "", "no main_config yet");
            fclose(fopen(fullfile(instance, "config", "main_config"), "w"));
            loc = deployedArchiveLocation(endpointRoot=endpoint, ctfRoot=root("noise_1"));
            test.verifyEqual(loc.instanceRoot, instance);
            loc = deployedArchiveLocation(endpointRoot="", ctfRoot=root("noise_1"));
            test.verifyEqual(loc.instanceRoot, "", "not on MPS");
        end

        function defaultLocationIsComputedOncePerCopy(test)
            % The fixture's stand-in deployedArchiveLocation counts its calls.
            deployed = test.applyFixture(prodserver.mcp.test.mixin.DeployedArchiveFixture("spy_1"));
            prodserver.mcp.handler.archiveCache(test.Name, action="set", value=1);
            for k = 1:100
                prodserver.mcp.handler.archiveCache(test.Name);
            end
            test.verifyEqual(deployed.calls(), 1);
        end

        function archiveScopeDoesNotTouchAppdata(test)
            prodserver.mcp.handler.archiveCache(test.Name, action="set", value=1);
            prodserver.mcp.handler.archiveCache(test.Name);
            set(test, "noise_1", 2);
            names = string(fieldnames(getappdata(0)));
            test.verifyFalse(any(startsWith(names, test.Name)), "no appdata key for the name");
        end

        function explicitCtfRootBypassesTheCachedLocation(test)
            import prodserver.mcp.handler.archiveCache
            archiveCache(test.Name, action="set", value="here");
            set(test, "other_1", "there");
            test.verifyEqual(archiveCache(test.Name), "here");
            test.verifyEqual(get(test, "other_1"), "there");
        end

        function archiveCacheNeverRaisesOnAMissingEntry(test)
            import prodserver.mcp.handler.archiveCache
            test.verifyEmpty(archiveCache(test.Name));
            archiveCache(test.Name, action="clear");
            archiveCache(test.Name, action="clearAll");
            test.verifyEmpty(archiveCache(test.Name));
        end
    end

    methods (Access = private)
        function set(test, folder, value)
            prodserver.mcp.handler.archiveCache(test.Name, action="set", value=value, ...
                ctfRoot=root(folder));
        end

        function v = get(test, folder)
            v = prodserver.mcp.handler.archiveCache(test.Name, ctfRoot=root(folder));
        end
    end
end

function r = root(folder)
% A deployed archive's ctfroot: <instance>/auto_deploy/<archive>_<n>.
    r = string(fullfile(tempdir, "instance", "auto_deploy", folder));
end
