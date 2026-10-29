classdef tBuildTests < matlab.unittest.TestCase
%tBuildTests Unit tests for the example parameter in prodserver.mcp.build.

% Copyright 2026 The MathWorks, Inc.

    properties
        tempFolder
    end

    methods (TestClassSetup)
        function quietUnobserved(test)
            % build warns if any input or output has no assigned type. But
            % that's not what we're testing here, so turn off that warning.
            test.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                "prodserver:mcp:UnobservedParameters"));
        end
    end

    methods(TestMethodSetup)
        function setup(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture

            tfolder = TemporaryFolderFixture(WithSuffix="buildTests");
            test.applyFixture(tfolder);
            test.tempFolder = tfolder.Folder;

            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods(Test)

        function copyOverwritesReadOnly(test)
            % Copy the JSON files from +internal into the temporary folder and
            % make them read-only. Then build, twice. Make the non-edited file
            % (archive_routes.json) read-only again between the builds. This
            % replicates a user-reported error when the package installs via
            % the AddOn explorer, which sets all the installed files to
            % read-only.

            function validateBuildModification(t0,t1)
                test.verifyEqual(numel(t0),numel(t1), ...
                    "Number of file records must match");
                for n = 1:numel(t0)
                    test.verifyEqual(t0(n).name,t1(n).name, ...
                        "File names must match, record " + string(n));
                    test.verifyNotEqual(t1(n).datenum,t0(n).datenum, ...
                        "File modification time must change: "+ ...
                        string(t1(n).name));
                    test.verifyNotEqual(t1(n).bytes,0, ...
                        "File must not be empty: " + string(t1(n).name));
                end
            end

            root = prodserver.mcp.internal.packageFolder;
            srcFolder = fullfile(root, "+prodserver", "+mcp", "+internal");
            sourceFiles = dir(fullfile(srcFolder, "*_routes.json"));
            for k = 1:numel(sourceFiles)
                % copyfile won't take multiple files as source inputs.
                copyfile(fullfile(sourceFiles(k).folder, sourceFiles(k).name), test.tempFolder);
                destinationPath = fullfile(test.tempFolder, sourceFiles(k).name);

                % "touch" the file -- set them all to zero length, so we
                % can tell if the later build changed them.
                fid = fopen(destinationPath,"w");
                fclose(fid);

                % Validate zero-length
                d = dir(destinationPath);
                test.verifyEqual(d.bytes,0,"Non-empty file: " + string(d.name));
                
                % Remove write permission
                fileattrib(destinationPath, "-w"); %#ok<FILEATTRIB>

                % Make sure we can't actually modify the read-only file
                % now.
                test.verifyError(@() writelines("**POOF**",destinationPath), ...
                    "MATLAB:table:write:FileOpenError");
            end

            % Get modification times of the JSON files.
            d0 = dir(fullfile(test.tempFolder,"*_routes.json"));

            % Pause to give file modification time some time to differ.
            pause(5);

            % Build should succeed
            prodserver.mcp.build("schemaComputeNoBlock", ...
                example=@() schemaComputeNoBlock(1.0, 2.0, 3.0), ...
                folder=test.tempFolder, archive="buildTestsReadOnly", ...
                stop=prodserver.mcp.BuildStage.Routes);

            % JSON files should have been modified by build.
            d1 = dir(fullfile(test.tempFolder,"*_routes.json"));
            validateBuildModification(d0,d1);

            % There shouldn't be an archive in the output folder
            archivePath = fullfile(test.tempFolder, "buildTestsReadOnly.ctf");
            test.verifyEqual(exist(archivePath, "file"), 0, ...
                "Archive should not exist before the archive stage");

            % All the JSON files should be writable
            for k = 1:numel(sourceFiles)
                filePath = fullfile(test.tempFolder, sourceFiles(k).name);
                test.verifyEqual(fileattrib(filePath, "+w"), true, ...
                    "JSON file should be writable"); %#ok<FILEATTRIB>
            end

            % Make archive_routes.json zero length and read-only
            archivePath = fullfile(test.tempFolder, "archive_routes.json");
            fid = fopen(archivePath, "w");
            fclose(fid);
            test.verifyEqual(dir(archivePath).bytes, 0, ...
                "archive_routes.json should be empty");
            fileattrib(archivePath, "-w"); %#ok<FILEATTRIB>

            % Going to repeat modification time test
            d0 = dir(fullfile(test.tempFolder,"*_routes.json"));
            pause(5);

            % Build again
            prodserver.mcp.build("schemaComputeNoBlock", ...
                example=@() schemaComputeNoBlock(1.0, 2.0, 3.0), ...
                folder=test.tempFolder, archive="buildTestsReadOnly", ...
                stop=prodserver.mcp.BuildStage.Routes);

            % JSON files should have been modified by build.
            d1 = dir(fullfile(test.tempFolder,"*_routes.json"));
            validateBuildModification(d0,d1);

            % All the JSON files should be writable
            for k = 1:numel(sourceFiles)
                filePath = fullfile(test.tempFolder, sourceFiles(k).name);
                [~,attr] = fileattrib(filePath); %#ok<FILEATTRIB>
                test.verifyEqual(attr.UserWrite, true, ...
                    "JSON file should be writable (build #2)"); 
            end
        end

        function testsGeneratesDefinition(test)
            import prodserver.mcp.MCPConstants

            fcn = "schemaComputeNoBlock";
            prodserver.mcp.build(fcn, ...
                example=@() schemaComputeNoBlock(1.0, 2.0, 3.0), ...
                folder=test.tempFolder, ...
                archive="buildTestsDef", stop="Definition");

            defFile = fullfile(test.tempFolder, MCPConstants.DefinitionFile);
            test.verifyEqual(exist(defFile, "file"), 2, ...
                "Definition file should exist");

            def = load(defFile);
            def = def.(MCPConstants.DefinitionVariable);
            names = cellfun(@(t)string(t.name), def.tools);
            test.verifyTrue(ismember(fcn, names), ...
                fcn + " not in definition");
        end

        function testsAndDefinitionErrors(test)
            fcn = "schemaComputeNoBlock";
            defs = prodserver.mcp.schema(fcn, ...
                @() schemaComputeNoBlock(1.0, 2.0, 3.0));

            test.verifyError(...
                @() prodserver.mcp.build(fcn, ...
                    example=@() schemaComputeNoBlock(1.0, 2.0, 3.0), ...
                    definition=defs, ...
                    folder=test.tempFolder, archive="conflict"), ...
                "prodserver:mcp:ExampleDefinitionConflict");
        end

        function testsAndWrapperErrors(test)
        % An observed definition calls the original function, so a wrapper
        % would be built into the archive and never called.
            fcn = "schemaComputeNoBlock";
            test.verifyError(...
                @() prodserver.mcp.build(fcn, ...
                    example=@() schemaComputeNoBlock(1.0, 2.0, 3.0), ...
                    wrapper="", folder=test.tempFolder, ...
                    archive="conflict", stop="Definition"), ...
                "prodserver:mcp:ExampleWrapperConflict");
        end

        function testsBuildsNoWrapper(test)
        % schemaColumnVector's (:,1) input would make the default (Auto)
        % generate a large-data wrapper. With example= it must not, and the
        % tool must call the function the definition was observed from.
            import prodserver.mcp.MCPConstants

            fcn = "schemaColumnVector";
            prodserver.mcp.build(fcn, ...
                example=@() schemaColumnVector((1:100)', 50), ...
                folder=test.tempFolder, ...
                archive="buildTestsNoWrapper", stop="Definition");

            test.verifyEqual(exist(fullfile(test.tempFolder, ...
                fcn + MCPConstants.WrapperFileSuffix + ".m"), "file"), 0, ...
                "No wrapper should be generated with example=");

            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);
            test.verifyEqual(string(def.signatures.(fcn).function), fcn);
        end

        function testsEmptyNoEffect(test)
            import prodserver.mcp.MCPConstants

            fcn = "schemaCompute";
            prodserver.mcp.build(fcn, example=[], ...
                folder=test.tempFolder, ...
                archive="buildTestsEmpty", stop="Definition");

            defFile = fullfile(test.tempFolder, MCPConstants.DefinitionFile);
            test.verifyEqual(exist(defFile, "file"), 2, ...
                "Definition file should exist via mcpDefinition path");
        end

        function testsMultiToolBuild(test)
            import prodserver.mcp.MCPConstants

            fcns = ["schemaComputeNoBlock", "schemaVectorNoBlock"];
            prodserver.mcp.build(fcns, ...
                example=@() exerciseMultiTool(), ...
                folder=test.tempFolder, ...
                archive="buildTestsMulti", stop="Definition");

            defFile = fullfile(test.tempFolder, MCPConstants.DefinitionFile);
            def = load(defFile);
            def = def.(MCPConstants.DefinitionVariable);
            names = cellfun(@(t)string(t.name), def.tools);
            for n = 1:numel(fcns)
                test.verifyTrue(ismember(fcns(n), names), ...
                    fcns(n) + " not in definition");
            end
        end

        function testsEncodingPerToolBuild(test)
            % One encoding per function, as without examples. schema takes
            % only one, so it used to be given the whole vector and fail.
            import prodserver.mcp.MCPConstants

            fcns = ["schemaComputeNoBlock", "schemaVectorNoBlock"];
            setappdata(0, "tBuildTestsExampleRuns", 0);
            clearRuns = onCleanup(@() rmappdata(0, "tBuildTestsExampleRuns"));
            prodserver.mcp.build(fcns, ...
                example=@() exerciseCounted(), ...
                encoding=["Invertible", "JSON"], ...
                folder=test.tempFolder, ...
                archive="buildTestsEncodings", stop="Definition");
            % Observed once, then each schema built with its encoding: an
            % example with side effects must not run once per encoding.
            test.verifyEqual(getappdata(0, "tBuildTestsExampleRuns"), 1, ...
                "The examples run once");

            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);
            tools = def.tools;
            if ~iscell(tools), tools = num2cell(tools); end
            names = cellfun(@(t) string(t.name), tools);
            invertible = tools{names == "schemaComputeNoBlock"}.inputSchema.properties;
            plain = tools{names == "schemaVectorNoBlock"}.inputSchema.properties;
            p = string(fieldnames(invertible));
            test.verifyTrue(prodserver.mcp.jsonrpc.isInvertibleSchema( ...
                invertible.(p(1))), "schemaComputeNoBlock: Invertible");
            p = string(fieldnames(plain));
            test.verifyFalse(prodserver.mcp.jsonrpc.isInvertibleSchema( ...
                plain.(p(1))), "schemaVectorNoBlock: JSON");
            test.verifyEqual(string(def.signatures.schemaComputeNoBlock.encoding), ...
                "Invertible");
            test.verifyEqual(string(def.signatures.schemaVectorNoBlock.encoding), ...
                "JSON");
        end

        function testsEncodingSizeMismatch(test)
            % One encoding for all, or one per function: anything else
            % used to misalign or index past the end.
            fcns = ["schemaComputeNoBlock", "schemaVectorNoBlock"];
            three = ["Invertible", "JSON", "JSON"];
            test.verifyError(@() prodserver.mcp.build(fcns, ...
                example=@() exerciseMultiTool(), encoding=three, ...
                folder=test.tempFolder, stop="Definition"), ...
                "prodserver:mcp:SizeMismatch");
            test.verifyError(@() prodserver.mcp.build(fcns, ...
                encoding=three, folder=test.tempFolder, stop="Definition"), ...
                "prodserver:mcp:SizeMismatch");
            test.verifyError(@() prodserver.mcp.schema(fcns, ...
                @() exerciseMultiTool(), encoding=three), ...
                "prodserver:mcp:SizeMismatch");
        end

        function restoresPath(test)
            p = path;
            prodserver.mcp.build("schemaComputeNoBlock", ...
                example=@() schemaComputeNoBlock(1.0, 2.0, 3.0), ...
                folder=test.tempFolder, ...
                archive="buildTestsPath", stop="Definition");
            test.verifyEqual(path, p);
        end

        function shadowedHandlerErrors(test)
        % Another copy of a route handler earlier on the path would be
        % built into the archive in place of this framework's.
            import matlab.unittest.fixtures.PathFixture
            shadow = fullfile(test.tempFolder, "shadow");
            pkg = fullfile(shadow, "+prodserver", "+mcp", "+internal");
            mkdir(pkg);
            writelines(["function mcpHandler()", "end"], ...
                fullfile(pkg, "mcpHandler.m"));
            test.applyFixture(PathFixture(shadow));
            test.verifyError(...
                @() prodserver.mcp.build("schemaComputeNoBlock", ...
                    folder=test.tempFolder, archive="shadowed", ...
                    stop="Definition"), ...
                "prodserver:mcp:FrameworkShadowed");
        end

        function shadowedResourceTool(test)
        % A user function with the same name as the built-in resource tool,
        % earlier on the path. build moves the built-in tools folder ahead
        % of it, unless that folder belongs to an installed package, which
        % build mustn't move. Then the user's function wins, and build
        % refuses to continue.
            import matlab.unittest.fixtures.PathFixture
            import prodserver.mcp.MCPConstants
            shadow = fullfile(test.tempFolder, "shadow");
            mkdir(shadow);
            tool = MCPConstants.ReadResourceTool;
            writelines(["function " + tool + "()", "end"], ...
                fullfile(shadow, tool + ".m"));
            test.applyFixture(PathFixture(shadow));
            build = @() prodserver.mcp.build("schemaComputeNoBlock", ...
                example=@() schemaComputeNoBlock(1.0, 2.0, 3.0), ...
                folder=test.tempFolder, archive="shadowed", ...
                stop="Definition");
            tools = fullfile(prodserver.mcp.internal.packageFolder(), ...
                "server", "tools");
            if prodserver.mcp.internal.isInstalledPackageFolder(tools)
                test.verifyError(build, "prodserver:mcp:FrameworkShadowed");
            else
                % Only the shadowing check is under test. Any other error
                % propagates and is reported as a test error.
                try
                    build();
                catch e
                    if e.identifier == "prodserver:mcp:FrameworkShadowed"
                        test.verifyFail(e.message);
                    else
                        rethrow(e);
                    end
                end
            end
        end

    end
end

function exerciseMultiTool()
    [~,~,~] = schemaComputeNoBlock(1.0, 2.0, 3.0);
    [~,~,~] = schemaVectorNoBlock([1.0, 2.0, 3.0], 2.0);
end

function exerciseCounted()
% exerciseMultiTool, counting its runs.
    setappdata(0, "tBuildTestsExampleRuns", getappdata(0, "tBuildTestsExampleRuns") + 1);
    exerciseMultiTool();
end
