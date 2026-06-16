classdef tZeroParameters < matlab.unittest.TestCase & ...
        prodserver.mcp.test.mixin.ExternalData

    properties
        toolsFolder
    end

    methods (TestClassSetup)

        function registerPackage(test)
            % Ensure that the functions being tested are on the path.
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            pkgFolder = fullfile(testFolder,"../../..");
            test.applyFixture(PathFixture(pkgFolder));
        end

        function managePath(test)
            % Put the toy tools on the path
            import matlab.unittest.fixtures.PathFixture
            folder = fileparts(mfilename("fullpath"));
            test.toolsFolder = fullfile(folder,"..", "..", "tools", ...
                "toyTools");
            test.applyFixture(PathFixture(test.toolsFolder));
        end

    end

    methods(Test)

        function defineZeroIn(test)
        % Function with zero inputs

            tool = "toyZeroInputs";

            % Vanilla argument list -- tools only.
            td = prodserver.mcp.internal.defineForMCP(tool,tool);

            % Known result
            expected = strtrim(fileread(fullfile(test.toolsFolder,tool+".json")));
            actual = jsonencode(td.tools{1});
            test.verifyEqual(actual,expected,"tool");
        end

        function defineZeroOut(test)

            tool = "toyZeroOutputs";

            % Vanilla argument list -- tools only.
            td = prodserver.mcp.internal.defineForMCP(tool,tool);

            % Known result
            expected = strtrim(fileread(fullfile(test.toolsFolder,tool+".json")));
            actual = jsonencode(td.tools{1});
            test.verifyEqual(actual,expected,"tool");
        end

        function wrapZeroIn(test)
            % Function with zero inputs

            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture

            tempDir = TemporaryFolderFixture(WithSuffix="z e r o");
            test.applyFixture(tempDir);
            tfolder = tempDir.Folder;

            tool = "toyZeroInputs";
            % Wrap it
            wrap = prodserver.mcp.internal.wrapForMCP(tool,"", tfolder);

            % Prepare output locations

            nURL = locate(test,"n",tfolder);
            heroURL = locate(test,"hero",tfolder);
            areaURL = locate(test,"area",tfolder);

            % Put the temp folder on the path
            test.applyFixture(PathFixture(tfolder));

            % Call the wrapper -- must set random seed to guarantee 
            % reproducible results for this tool.
            rng(39,"multFibonacci");
            [~,fcn] = fileparts(wrap);
            [extent,cover] = feval(fcn,nURL,heroURL,areaURL);

            % Expected result with this random seed.
            x = {12, 10, 7};
            y = {17, 13, 24};
            z = {25, 13, 25};
            expectedArea = [90,60,84];
            expectedHero = struct("x",x, "y", y, "z", z);
            expectedN = [18,14,8];
            expectedExtent = 146;
            expectedCover = 234;

            % Verify results
            test.verifyEqual(cover,expectedCover,"cover");
            test.verifyEqual(extent,expectedExtent,"extent");
            test.verifyEqual(fetch(test,nURL),expectedN,"n");
            test.verifyEqual(fetch(test,heroURL),expectedHero,"hero");
            test.verifyEqual(fetch(test,areaURL),expectedArea,"area");
        end

        function wrapZeroOut(test)

            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture

            tempDir = TemporaryFolderFixture(WithSuffix="z e r o");
            test.applyFixture(tempDir);
            tfolder = tempDir.Folder;

            % Write import options to tool definition file (this is done by
            % prodserver.mcp.build in user workflows).
            importer.exchange = delimitedTextImportOptions(DataLines=1,...
                ImportErrorRule="error");
            io.(MCPConstants.ImporterVariable) = importer;
            defFile = fullfile(tfolder,MCPConstants.DefinitionFile);
            save(defFile,"-struct","io");

            tool = "toyZeroOutputs";

            % Wrap it
            wrap = prodserver.mcp.internal.wrapForMCP(tool,"", tfolder, ...
                import="exchange");

            % Put the temp folder on the path
            test.applyFixture(PathFixture(tfolder));

            [exchangeURL, exchangeFile] = locate(test,"exchange",tfolder, ...
                ext="csv");
            [uuidURL, uuidFile] = locate(test,"uuid",tfolder,ext="csv");

            swap = ["-,_", "a,A", "b,B", "c,C", "d,D", "e,E", "f,F"];
            writelines(swap,exchangeFile);

            n = 13;

            [~,fcn] = fileparts(wrap);
            feval(fcn,n,exchangeURL,uuidFile);

            u = fetch(test,uuidURL,import=importer.exchange);

            % Upper-case each UUID and replace - with _. This
            % transformation should leave u unchanged.
            uu = upper(u);
            uuu = replace(uu,"-","_");
            test.verifyEqual(u,uuu,"UUID");
        end
    end
end