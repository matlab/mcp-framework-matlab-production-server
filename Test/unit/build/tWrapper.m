classdef tWrapper < matlab.unittest.TestCase 

% Copyright 2025-2026 The MathWorks, Inc.

    properties
        toolFolder
        tempFolder
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

    methods (TestMethodSetup)

        function scratchSpace(test)
            % Temporary folder to contain wrappers
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            test.tempFolder = tFolder.Folder;
        end

    end


    methods
        function validateWrapperText(test,tool,code)
            % Grab the known-good wrapper (which "code" should match
            % exactly).
            wrapFile = fullfile(test.toolFolder,tool+".wrap");
            wrap = readlines(wrapFile);

            % The generated code may contain a unique UUID-named variable. 
            % In order for the .wrap file to match exactly that variable 
            % must be injected into the .wrap file.
            varPattern = "v" + alphanumericsPattern + asManyOfPattern("_"+alphanumericsPattern,4,4);
            marshalVar = unique(extract(code,varPattern));
            if ~isempty(marshalVar)
                test.verifyEqual(numel(marshalVar),1,"Unique UUID variables.")
                wrap = replace(wrap,"!marshalVar",marshalVar);
                wrap = strjoin(wrap,newline);
            end

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

        function schemaLiteral(test)
        % Manage schemas of literal variables. Make sure they appear
        % in the tool description.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.Constants
            import matlab.unittest.fixtures.PathFixture

            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireParamTools());
            test.toolFolder = rtt.toolFolder;

            % Wrapper folder must be on the path so we can call the
            % wrapper.
            test.applyFixture(PathFixture(test.tempFolder));

            % Generate wrapper for a function that uses a client-written
            % schema.
            fcn = "literalSchemas";

            % Force wrapper generation (override Auto default) to test
            % wrapper text correctness with all-literal parameters.
            prodserver.mcp.build(fcn,folder=test.tempFolder,stop="Definition",...
                encoding="Invertible",wrapper="");

            % Wrappers must exist
            wrap = fullfile(test.tempFolder,fcn + "MCP.m");

            % Wrapper must match golden file.
            validateWrapperFile(test,fcn,wrap);

            % Wrapper must actually work
            xC = num2cell(randi(100,[11,1]));
            yC = num2cell(randi(100,[11,1]));
            originC = struct("x", xC, "y", yC);
            radius = num2cell(randperm(11))';
            circle = struct("origin", originC, "radius", radius);

            xS = num2cell(randi(100,[13,1]));
            yS = num2cell(randi(100,[13,1]));
            originS = struct("x", xS, "y", yS);
            side = num2cell(randperm(13))';
            square = struct("side", side, "origin", originS);

            [a.sortedC, a.sortedS, a.areaC, a.areaS] = literalSchemas(...
                circle, square);
            [e.sortedC, e.sortedS, e.areaC, e.areaS] = literalSchemasMCP(...
                circle, square);
            test.verifyEqual(a,e,"Something went wrong");
            test.verifyEqual([a.sortedC.radius],1:11,"Circle sort order wrong");
            test.verifyEqual([a.sortedS.side],1:13,"Side sort order wrong");

            % Load definition and check for schemas
            td = load(fullfile(test.tempFolder,MCPConstants.DefinitionFile));
            td = td.(MCPConstants.DefinitionVariable);

            %
            % Inputs
            %

            % Circle
            actual = td.tools{1}.inputSchema.properties.circle.properties.data;
            expected = jsondecode(fileread(fullfile(test.toolFolder,"circle.json")));
            test.verifyEqual(actual.type,expected.type,"Circle type not equal");
            test.verifyEqual(actual.items,expected.items,"Circle items not equal");
            test.verifyEqual(double(actual.maxItems),11); % See literalSchema.m

            % Square
            actual = td.tools{1}.inputSchema.properties.square.properties.data;
            expected = jsondecode(fileread(fullfile(test.toolFolder,"square.json")));
            test.verifyEqual(actual.type,expected.type,"Square type not equal");
            test.verifyEqual(actual.items,expected.items,"Square items not equal");
            test.verifyEqual(double(actual.maxItems),13); % See literalSchema.m

            %
            % Outputs
            %

            % sortedC
            actual = td.tools{1}.outputSchema.properties.sortedC.properties.data;
            expected = jsondecode(fileread(fullfile(test.toolFolder,"circle.json")));
            test.verifyEqual(actual.type,expected.type,"sortedC type not equal");
            test.verifyEqual(actual.items,expected.items,"sortedC items not equal");
            test.verifyEqual(double(actual.maxItems),11); % See literalSchema.m

            % sortedS
            actual = td.tools{1}.outputSchema.properties.sortedS.properties.data;
            expected = jsondecode(fileread(fullfile(test.toolFolder,"square.json")));
            test.verifyEqual(actual.type,expected.type,"sortedS type not equal");
            test.verifyEqual(actual.items,expected.items,"sortedS items not equal");
            test.verifyEqual(double(actual.maxItems),13); % See literalSchema.m

            % Schema pragma does not appear in description of any input or
            % output.

            param = td.tools{1}.inputSchema.properties.circle;
            test.verifyFalse(any(contains(param.description,Constants.Schema)),...
                "Found schema in circle description");

            param = td.tools{1}.inputSchema.properties.square;
            test.verifyFalse(any(contains(param.description,Constants.Schema)),...
                "Found schema in square description");

            param = td.tools{1}.outputSchema.properties.sortedC;
            test.verifyFalse(any(contains(param.description,Constants.Schema)),...
                "Found schema in sortedC description");

            param = td.tools{1}.outputSchema.properties.sortedS;
            test.verifyFalse(any(contains(param.description,Constants.Schema)),...
                "Found schema in sortedS description");

        end

        function schemaLiteralAndExternal(test)
        % Manage schemas of a tool with both external and literal 
        % variables. Make sure all schemas appear in the tool description.

            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.Constants

            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireParamTools());
            test.toolFolder = rtt.toolFolder;

            fcn = "litAndExtSchemas";

        end

        function schemaExternal(test)
        % Manage schemas of externalized variables. Make sure they appear
        % in the tool description.

            import prodserver.mcp.MCPConstants

            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.toolFolder = rtt.toolFolder;

            % Generate wrapper for a function that uses a client-written
            % schema.
            fcn = "toyFileSchema";

            % Vanilla argument list. Generate wrappers and tool definition
            % but not archive.
            prodserver.mcp.build(fcn,folder=test.tempFolder,stop="Definition",...
                encoding="Invertible");

            % Wrappers must exist
            wrap = fullfile(test.tempFolder,fcn + "MCP.m");

            % Wrapper must match golden file.
            validateWrapperFile(test,fcn,wrap);

            % Definition must contain schema
            def = load(fullfile(test.tempFolder,MCPConstants.DefinitionFile));
            test.verifyTrue(isfield(def.mcpToolDefinition.tools{1}, ...
                MCPConstants.DefsField), "$defs missing");
            test.verifyTrue(isfield(def.mcpToolDefinition.tools{1}.(MCPConstants.DefsField),"inputSchema"), ...
                "inputSchema field missing");
            test.verifyTrue(isfield(def.mcpToolDefinition.tools{1}.(MCPConstants.DefsField),"outputSchema"), ...
                "outputSchema field missing");

            % Input r and output z have been externalized. Their schemas
            % must be in the MCPConstants.DefsField of the definition 
            % structure.
            d = def.mcpToolDefinition.tools{1}.(MCPConstants.DefsField);
            test.verifyTrue(isfield(d.inputSchema,"rURL"),"rURL missing");
            test.verifyTrue(isfield(d.outputSchema,"zURL"),"zURL missing");

            triangle = fileread(fullfile(test.toolFolder,"triangle.json"));
            triangle = jsondecode(triangle);
            rURL = rmfield(d.inputSchema.rURL,"description");
            zURL = rmfield(d.outputSchema.zURL,"description");
            test.verifyEqual(rURL.oneOf{2}.properties.data,triangle);
            test.verifyEqual(zURL.oneOf{2}.properties.data,triangle);

        end

        function wrapMyriad(test)

            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.toolFolder = rtt.toolFolder;

            % Generate wrappers for three tools
            fcn = ["toyToolOne", "toyToolTwo", "toyToolThree"];

            % Vanilla argument list. Generate wrappers but not archive.
            types.geom = "float";
            prodserver.mcp.build(fcn, folder=test.tempFolder,stop="Wrapper",...
                typemap=types, encoding="Invertible");

            % Wrappers must exist
            wrap = fullfile(test.tempFolder,fcn + "MCP.m");

            % Wrappers must match golden files.
            for n = 1:numel(wrap)
                validateWrapperFile(test,fcn(n),wrap(n));
            end

        end
    end
end
