classdef tOptionalWrapper < matlab.unittest.TestCase

    properties
        toolFolder
    end

    methods(TestClassSetup)
        function initTest(test)
            testFolder = fileparts(mfilename("fullpath"));
            test.toolFolder = fullfile(testFolder,"..","..","tools", ...
                "toyTools");
        end
    end

    methods(Test)

        function starChart(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            import prodserver.mcp.MCPConstants

            tempFolder = TemporaryFolderFixture;
            applyFixture(test,tempFolder);
            tfolder = tempFolder.Folder;

            fcn = "toyURLOptions";

            % Add the tools folder to the path.
            test.applyFixture(PathFixture(test.toolFolder));

            % Import options for string matrix files
            iOpts = delimitedTextImportOptions(DataLines=1,...
                ImportErrorRule="error");

            % Importer object
            [importer.ngc, importer.constellation, importer.messier, ...
                importer.name] = deal(iOpts);

            % Generate wrappers and build -- only generate wrapper and
            % definition. Don't build the archive, because that takes a long
            % time.
            prodserver.mcp.build(fcn, folder=tfolder, stop="Definition", ...
                import=importer);

            % Add the temporary folder to the path.
            test.applyFixture(PathFixture(tfolder));

            % Call it -- call the original for the expected value, the
            % wrapper for the actual value. They'd better match.
            tool = fcn + MCPConstants.WrapperFileSuffix;

            dataFolder = fullfile(test.toolFolder,"data");

            ngcFile = fullfile(dataFolder,"DeepSkyNGC.csv");
            ngcURL = "file:" + ngcFile;
            ngc = readmatrix(ngcFile,iOpts);

            raFile = fullfile(dataFolder,"DeepSkyRA.csv");
            raURL = "file:" + raFile;
            ra = readmatrix(raFile);

            decFile = fullfile(dataFolder,"DeepSkyDec.csv");
            decURL = "file:" + decFile;
            dec = readmatrix(decFile);

            messierFile = fullfile(dataFolder,"DeepSkyMessier.csv");
            messierURL = "file:" + messierFile;
            messier = readmatrix(messierFile,iOpts);

            expected = feval(fcn,ngc,ra,dec,messier=messier);
            actual = feval(tool,ngcURL,raURL,decURL,messierURL=messierURL);
            test.verifyEqual(actual,expected,"messier optional input");
        end
    end

end