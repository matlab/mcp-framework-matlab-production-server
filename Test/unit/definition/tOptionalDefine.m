classdef tOptionalDefine < matlab.unittest.TestCase & ...
        prodserver.mcp.test.mixin.ExternalData

% Copyright 2025-2026 The MathWorks, Inc.

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

        function requireToyTools(test)
            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.toolsFolder = rtt.toolFolder;
        end

    end

    methods (TestMethodSetup)

        function switchContext(~)
            % Clear the tool definition cache
            prodserver.mcp.handler.toolServices(action="clear");
        end
    end

    methods (Test)

        function defineOptionalScalars(test)
            % Generate definition for tool with optional scalar inputs.

            % Generate definitions for tools
            tool = "toyScalarOptions";

            % Vanilla argument list -- tools only, no GenAI.
            td = prodserver.mcp.internal.defineForMCP(tool,tool);

            % Known result
            expected = strtrim(fileread(fullfile(test.toolsFolder,tool+".json")));
            actual = jsonencode(td.tools{1});
            test.verifyEqual(actual,expected,"tool");

        end

        function defineOptionalNVScalars(test)
        % Generate definition for tool with optional scalar inputs.

            % Generate definitions for tools
            tool = "toyScalarNVOptions";

            % Vanilla argument list -- tools only, no GenAI.
            td = prodserver.mcp.internal.defineForMCP(tool,tool);

            % Known result
            expected = strtrim(fileread(fullfile(test.toolsFolder,tool+".json")));
            actual = jsonencode(td.tools{1});
            test.verifyEqual(actual,expected,"tool");

        end

        function wrapAndDefineOptionalURL(test)
        % Generate definition for tool with optional externalized inputs.

            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture

            tempDir = TemporaryFolderFixture(WithSuffix="1 9 8 4");
            test.applyFixture(tempDir);
            tfolder = tempDir.Folder;

            % Write import options to tool definition file (this is done by
            % prodserver.mcp.build in user workflows).
            iOpts = delimitedTextImportOptions(DataLines=1,...
                ImportErrorRule="error");
            [importer.ngc, importer.constellation, importer.messier, ...
                importer.name] = deal(iOpts);
            io.(MCPConstants.ImporterVariable) = importer;
            defFile = fullfile(tfolder,MCPConstants.DefinitionFile);
            save(defFile,"-struct","io");

            % Generate wrapper 
            fcn = "toyURLOptions";
           
            wrap = prodserver.mcp.internal.wrapForMCP(fcn,"", tfolder, ...
                import=fieldnames(importer));

            expectedFile = fullfile(tfolder,fcn+MCPConstants.WrapperFileSuffix+".m");
            test.verifyEqual(exist(expectedFile,"file"),2,fcn);
            test.verifyEqual(wrap,expectedFile);

            % Add the temporary folder to the path.
            test.applyFixture(PathFixture(tfolder));

            % Call it -- call the original for the expected value, the
            % wrapper for the actual value. They'd better match.
            tool = fcn + MCPConstants.WrapperFileSuffix;

            dataFolder = fullfile(test.toolsFolder,"data");

            ngcURL = source(test,"DeepSkyNGC",dataFolder,ext="csv");
            ngc = fetch(test,ngcURL,import=iOpts);

            raURL = source(test,"DeepSkyRA",dataFolder,ext="csv");
            ra = fetch(test,raURL);

            decURL = source(test,"DeepSkyDec",dataFolder,ext="csv");
            dec = fetch(test,decURL);

            % No optional inputs
            expected = feval(fcn,ngc,ra,dec);
            actual = feval(tool,ngcURL,raURL,decURL);
            test.verifyEqual(actual,expected,"No optional inputs");

            % Get optional data 

            constellationURL = source(test,"DeepSkyConstellation",dataFolder,ext="csv");
            constellation = fetch(test,constellationURL,import=iOpts);

            nameURL = source(test,"DeepSkyName",dataFolder,ext="csv");
            name = fetch(test,nameURL,import=iOpts);

            messierURL = source(test,"DeepSkyMessier",dataFolder,ext="csv");
            messier = fetch(test,messierURL,import=iOpts);

            % One optional input
            expected = feval(fcn,ngc,ra,dec,constellation=constellation);
            actual = feval(tool,ngcURL,raURL,decURL,constellationURL=constellationURL);
            test.verifyEqual(actual,expected,"constellation optional input");

            expected = feval(fcn,ngc,ra,dec,messier=messier);
            actual = feval(tool,ngcURL,raURL,decURL,messierURL=messierURL);
            test.verifyEqual(actual,expected,"messier optional input");

            expected = feval(fcn,ngc,ra,dec,name=name);
            actual = feval(tool,ngcURL,raURL,decURL,nameURL=nameURL);
            test.verifyEqual(actual,expected,"name optional input");

            % Two optional inputs -- not all combinations.
            expected = feval(fcn,ngc,ra,dec,messier=messier, ...
                constellation=constellation);
            actual = feval(tool,ngcURL,raURL,decURL,messierURL=messierURL, ...
                constellationURL=constellationURL);
            test.verifyEqual(actual,expected,"messier+constellation optional input");

            % All optional inputs
            expected = feval(fcn,ngc,ra,dec,messier=messier, ...
                constellation=constellation,name=name);
            actual = feval(tool,ngcURL,raURL,decURL,messierURL=messierURL, ...
                constellationURL=constellationURL,nameURL=nameURL);
            test.verifyEqual(actual,expected,"All optional inputs");

            % Generate definition from wrapper
            td = prodserver.mcp.internal.defineForMCP(fcn,tool);

            % Known result
            expected = strtrim(fileread(fullfile(test.toolsFolder,tool+".json")));
            actual = jsonencode(td.tools{1});
            test.verifyEqual(actual,expected,"tool");
        end

        function defineOptionalMixed(test)
        % Generate definition for tool with scalar and externalized inputs.

        end

        function wrapOptionalNVScalars(test)

            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture

            tempDir = TemporaryFolderFixture(WithSuffix="1 9 8 4");
            test.applyFixture(tempDir);
            tfolder = tempDir.Folder;

            % Generate wrapper 
            fcn = "toyScalarNVOptions"; 

            wrap = prodserver.mcp.internal.wrapForMCP(fcn,"", tfolder);

            expectedFile = fullfile(tfolder,fcn+MCPConstants.WrapperFileSuffix+".m");
            test.verifyEqual(exist(expectedFile,"file"),2,fcn);
            test.verifyEqual(wrap,expectedFile);

            % Add the temporary folder to the path.
            test.applyFixture(PathFixture(tfolder));

            % Call it -- call the original for the expected value, the
            % wrapper for the actual value. They'd better match.
            wfcn = fcn + MCPConstants.WrapperFileSuffix;

            % Specify required only
            y = 1936;
            expected = feval(fcn,y);
            actual = feval(wfcn,y);
            test.verifyEqual(actual,expected,"Y = " + string(y));

            % Specify all optional
            y = 1947;
            make = "Bell";
            model = "XS-1";
            range = 20;
            mpg = 0.03311;
            expected = feval(fcn,y,make=make,range=range,model=model,mpg=mpg);
            actual = feval(wfcn,y,make=make,range=range,model=model,mpg=mpg);
            test.verifyEqual(actual,expected,"Y = " + string(y));

            % Specify one optional
            y = 1949;
            range = 713;
            expected = feval(fcn,y,range=range);
            actual = feval(wfcn,y,range=range);
            test.verifyEqual(actual,expected,"Y = " + string(y));

            % Specify three optional
            y = 1954;
            model = "Super Constellation";
            range = 4480;
            mpg = 0.8699;
            expected = feval(fcn,y,range=range,model=model,mpg=mpg);
            actual = feval(wfcn,y,range=range,model=model,mpg=mpg);
            test.verifyEqual(actual,expected,"Y = " + string(y));
        end

    end

end