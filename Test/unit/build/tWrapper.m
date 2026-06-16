classdef tWrapper < matlab.unittest.TestCase 

    properties
        toolFolder
    end

    methods (TestClassSetup)

        function registerPackage(test)
            % Ensure that the functions being tested are on the path.
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            pkgFolder = fullfile(testFolder,"../../..");
            test.applyFixture(PathFixture(pkgFolder));
        end

        function initPath(test)
            % Put the toyTools folder on the path.
            import matlab.unittest.fixtures.PathFixture
            test.toolFolder = fullfile(fileparts(mfilename("fullpath")),...
                "..", "..", "tools","toyTools");
            test.applyFixture(PathFixture(test.toolFolder));
        end
    end

    methods
        function validateWrapperText(test,tool,code)
            % Grab the known-good wrapper (which "code" should match
            % exactly).
            wrapFile = fullfile(test.toolFolder,tool+".wrap");
            wrap = readlines(wrapFile);

            % The generated code contains a unique UUID-named variable. In
            % order for the .wrap file to match exactly that variable must
            % be injected into the .wrap file.
            varPattern = "v" + alphanumericsPattern + asManyOfPattern("_"+alphanumericsPattern,4,4);
            marshalVar = unique(extract(code,varPattern));
            test.verifyEqual(numel(marshalVar),1,"Unique UUID variables.")
            wrap = replace(wrap,"!marshalVar",marshalVar);
            wrap = strjoin(wrap,newline);

            % Generated wrapper should be identical to "golden file".
            % Compare line by line to aid debugging / failure
            % identification.
            code = split(code,newline);
            wrap = split(wrap,newline);
            test.verifyEqual(numel(wrap),numel(code),"Wrong number of lines in " + tool);
            for n = 1:numel(code)
                test.verifyEqual(code(n),wrap(n),"Line " + string(n) + ...
                    ". Generated code: " + tool);
                if strcmp(code(n),wrap(n)) == 0
                    break;
                end
            end
        end

        function validateWrapperFile(test,tool,wrapFile)
        % Compare the contents of wrapFile to a known good wrapper for
        % tool.
            test.verifyEqual(exist(wrapFile,"file"),2,wrapFile);
            wrapCode = readlines(wrapFile);
            wrapCode = strjoin(wrapCode,newline);
            validateWrapperText(test,tool,wrapCode);
        end
    end

    methods(Test)

        function wrapMyriad(test)

            % Temporary folder to contain wrappers
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            wrapFolder = tFolder.Folder;

            % Generate wrappers for three tools
            fcn = ["toyToolOne", "toyToolTwo", "toyToolThree"];

            % Vanilla argument list. Generate wrappers but not archive.
            prodserver.mcp.build(fcn, folder=wrapFolder,stop="Wrapper");

            % Wrappers must exist
            wrap = fullfile(wrapFolder,fcn + "MCP.m");

            % Wrappers must match golden files.
            for n = 1:numel(wrap)
                validateWrapperFile(test,fcn(n),wrap(n));
            end

        end
    end
end
