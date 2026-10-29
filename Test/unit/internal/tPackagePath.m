classdef tPackagePath < matlab.unittest.TestCase
%tPackagePath Tests for the functions that keep build, schema and
%classifyExample from disturbing an installed package's path entries:
%canonicalFolder, isOnPath, isInstalledPackageFolder and prependPath.

% Copyright 2026 The MathWorks, Inc.

    properties
        tempFolder
        pkgRoot
        member
        draftRoot
    end

    properties (Constant)
        ReorderID = "MATLAB:mpath:PackagesBrokenAsAtomicUnitDueToReorderedEntries"
    end

    methods(TestClassSetup)
        function installPackage(test)
        % A package installed in place for this MATLAB session only. Its
        % root holds one member folder, tools, and a folder that isn't a
        % member, Examples. A second package is created but not installed.
            import matlab.unittest.fixtures.TemporaryFolderFixture

            tfolder = TemporaryFolderFixture(WithSuffix="packagePath");
            test.applyFixture(tfolder);
            test.tempFolder = string(tfolder.Folder);

            [~, leaf] = fileparts(test.tempFolder);
            name = matlab.lang.makeValidName("mcpTestPkg_" + leaf);
            test.pkgRoot = fullfile(test.tempFolder, "pkg");
            test.member = fullfile(test.pkgRoot, "tools");
            mkdir(fullfile(test.member, "below"));
            mkdir(fullfile(test.pkgRoot, "Examples"));
            mkdir(fullfile(test.tempFolder, "other"));
            writelines(["function mcpTestPkgTool()", "end"], ...
                fullfile(test.member, "mcpTestPkgTool.m"));

            pkg = mpmcreate(name, test.pkgRoot, ...
                IncludeSubfolders=false, Install=false);
            addFolder(pkg, test.member);
            mpminstall(test.pkgRoot, InPlace=true, Temporary=true, ...
                Prompt=false, Verbosity="quiet");
            test.addTeardown(@()mpmuninstall(name, Prompt=false, ...
                Verbosity="quiet"));

            test.draftRoot = fullfile(test.tempFolder, "draft");
            mkdir(fullfile(test.draftRoot, "tools"));
            draft = mpmcreate(name + "Draft", test.draftRoot, ...
                IncludeSubfolders=false, Install=false);
            addFolder(draft, fullfile(test.draftRoot, "tools"));
        end
    end

    methods(TestMethodSetup)
        function setup(test)
            import matlab.unittest.fixtures.CurrentFolderFixture
            test.applyFixture(CurrentFolderFixture(test.tempFolder));
            p = path;
            test.addTeardown(@()path(p));
        end
    end

    methods(Test)

        function canonicalSpellings(test)
            import prodserver.mcp.internal.canonicalFolder
            expected = canonicalFolder(test.member);
            test.verifyEqual(canonicalFolder(replace(test.member, "\", "/")), expected);
            test.verifyEqual(canonicalFolder(test.member + filesep), expected);
            test.verifyEqual(canonicalFolder(fullfile("pkg", "tools")), expected);
            test.verifyEqual(canonicalFolder(fullfile(".", "pkg", "tools")), expected);
            if ispc || ismac
                test.verifyEqual(canonicalFolder(upper(test.member)), expected);
            end
        end

        function canonicalMissingFolder(test)
            import prodserver.mcp.internal.canonicalFolder
            missing = fullfile(test.tempFolder, "missing") + filesep;
            test.verifyEqual(canonicalFolder(missing), ...
                canonicalFolder(fullfile(test.tempFolder, "missing")));
        end

        function canonicalArray(test)
            import prodserver.mcp.internal.canonicalFolder
            f = [test.member, fullfile(test.tempFolder, "other")];
            c = canonicalFolder(f);
            test.verifySize(c, size(f));
            test.verifyEqual(c(2), canonicalFolder(f(2)));
        end

        function onPathSpellings(test)
            import prodserver.mcp.internal.isOnPath
            other = fullfile(test.tempFolder, "other");
            addpath(other);
            test.verifyTrue(isOnPath(other));
            test.verifyTrue(isOnPath(replace(other, "\", "/")));
            test.verifyTrue(isOnPath(other + filesep));
            test.verifyTrue(isOnPath("other"));
            test.verifyFalse(isOnPath(fullfile(test.pkgRoot, "Examples")));
            test.verifyFalse(isOnPath(fullfile(test.tempFolder, "missing")));
        end

        function onPathArray(test)
            import prodserver.mcp.internal.isOnPath
            tf = isOnPath([test.member; fullfile(test.tempFolder, "other")]);
            test.verifyEqual(tf, [true; false]);
        end

        function installedMembers(test)
            import prodserver.mcp.internal.isInstalledPackageFolder
            test.verifyTrue(isInstalledPackageFolder(test.pkgRoot));
            test.verifyTrue(isInstalledPackageFolder(test.member));
            test.verifyTrue(isInstalledPackageFolder(replace(test.member, "\", "/") + "/"));
            test.verifyFalse(isInstalledPackageFolder(fullfile(test.member, "below")));
            test.verifyFalse(isInstalledPackageFolder(fullfile(test.pkgRoot, "Examples")));
            test.verifyFalse(isInstalledPackageFolder(fullfile(test.tempFolder, "other")));
            test.verifyFalse(isInstalledPackageFolder(fullfile(test.tempFolder, "missing")));
        end

        function installedArray(test)
            import prodserver.mcp.internal.isInstalledPackageFolder
            tf = isInstalledPackageFolder([test.pkgRoot, test.member, ...
                fullfile(test.pkgRoot, "Examples")]);
            test.verifyEqual(tf, [true, true, false]);
        end

        function uninstalledPackageIgnored(test)
        % A package definition alone doesn't make MATLAB enforce the order
        % of the package's folders on the path.
            import prodserver.mcp.internal.isInstalledPackageFolder
            test.verifyFalse(isInstalledPackageFolder(test.draftRoot));
            test.verifyFalse(isInstalledPackageFolder( ...
                fullfile(test.draftRoot, "tools")));
        end

        function addpathWarns(test)
        % The warning prependPath avoids. If this fails, MATLAB no longer
        % enforces package order and prependPath can simply call addpath.
            test.verifyWarning(@()addpath(test.member), test.ReorderID);
        end

        function prependLeavesInstalledMember(test)
            import prodserver.mcp.internal.prependPath
            addpath(fullfile(test.tempFolder, "other"));
            p = path;
            test.verifyWarningFree(@()prependPath(test.member));
            test.verifyWarningFree(@()prependPath(test.pkgRoot));
            test.verifyEqual(path, p);
        end

        function prependMovesOtherFolder(test)
            import prodserver.mcp.internal.prependPath
            other = fullfile(test.tempFolder, "other");
            addpath(other, "-end");
            prependPath(other);
            first = extractBefore(string(path), pathsep);
            test.verifyEqual(first, other);
        end

        function prependMovesNonMember(test)
        % A folder in an installed package that isn't a member, like
        % Examples, isn't in MATLAB's keeping.
            import prodserver.mcp.internal.prependPath
            examples = fullfile(test.pkgRoot, "Examples");
            test.verifyWarningFree(@()prependPath(examples));
            first = extractBefore(string(path), pathsep);
            test.verifyEqual(first, examples);
        end

    end
end
