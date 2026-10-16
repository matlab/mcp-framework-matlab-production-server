classdef tBuildTests < matlab.unittest.TestCase
%tBuildTests Unit tests for the example parameter in prodserver.mcp.build.

% Copyright 2026 The MathWorks, Inc.

    properties
        tempFolder
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

            % Make archive_routes.json read-only and zero length
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
                test.verifyEqual(fileattrib(filePath, "+w"), true, ...
                    "JSON file should be writable (build #2)"); %#ok<FILEATTRIB>
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

    end
end

function exerciseMultiTool()
    [~,~,~] = schemaComputeNoBlock(1.0, 2.0, 3.0);
    [~,~,~] = schemaVectorNoBlock([1.0, 2.0, 3.0], 2.0);
end
