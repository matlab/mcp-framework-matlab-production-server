classdef tDefinition < matlab.unittest.TestCase

    properties
        exampleFolder
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

        function initTest(test)
            testFolder = fileparts(mfilename("fullpath"));
            test.exampleFolder = fullfile(testFolder,"..","..","..", ...
                "Examples");
            test.toolsFolder = fullfile(testFolder,"..", "..", "tools", ...
                "toyTools");
        end

    end

    methods (Test)

        function define(test)
        % Define a single tool. Test definition against known good file.

            % Put the earthquake example folder on the path.
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(PathFixture(fullfile(test.exampleFolder,...
                "Earthquake")));

            td = prodserver.mcp.internal.mcpDefinition(...
                "plotTrajectories", "plotTrajectoriesMCP");
            definition.tools = { td.tools };
            definition.signatures = { td.signatures };

            % Send definition round trip through JSON so it matches
            % expectedDefinition exactly.
            definition = jsondecode(jsonencode(definition));

            expectedDefinition = jsondecode(...
                fileread("plotTrajectories.json"));

            test.verifyEqual(definition,expectedDefinition);

        end

        function wrapper(test)
        % Define a tool with a wrapper. Ensure tool is known by tool
        % name, not wrapper name.

            % Put the toy tools on the path
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(PathFixture(test.toolsFolder));

            % Generate definitions for  tools
            tool = "toyToolOne";
            wrapper = "toyToolOneMCP";
            % Vanilla argument list -- tools only, no GenAI.
            td = prodserver.mcp.internal.defineForMCP(tool,wrapper);
          
            test.verifyEqual(td.tools{1}.name,tool)
            
        end

        function myriad(test)
        % Define multiple tools. Test definition against known good file.

            % Put the toy tools on the path
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(PathFixture(test.toolsFolder));

            % Generate definitions for three tools
            tools = ["toyToolOne", "toyToolTwo", "toyToolThree"];
            % Vanilla argument list -- tools only, no GenAI.
            types.geom = "double";
            td = prodserver.mcp.internal.defineForMCP(tools,tools, ...
                typemap=types);
            definition.tools = td.tools;
            definition.signatures = td.signatures;

            % Send definition round trip through JSON so it matches
            % expectedDefinition exactly.
            definition = jsondecode(jsonencode(definition));

            expectedDefinition = jsondecode(...
                fileread(fullfile(test.toolsFolder,"toyTools.json")));

            test.verifyEqual(definition,expectedDefinition);
        end

        function negative(test)
        % Poke the bear. 

            % Put the badly commented MATLAB files on the path.
            import matlab.unittest.fixtures.PathFixture
            folder = fileparts(mfilename("fullpath"));
            test.applyFixture(PathFixture(fullfile(folder,"badExamples")));

            % No such file, alas.
            test.verifyError(@()prodserver.mcp.internal.mcpDefinition( ...
                "solveEverything", "infallibleOracle"), "prodserver:mcp:ToolFcnNotFound");

            % Missing input block
            test.verifyError(@()prodserver.mcp.internal.mcpDefinition( ...
                "noArgBlocks", "noArgBlocks"),"prodserver:mcp:InputArgBlockRequired");

            % Missing output block
            test.verifyError(@()prodserver.mcp.internal.mcpDefinition( ...
                "noOutputBlock", "noOutputBlock"),"prodserver:mcp:OutputArgBlockRequired");

            % Missing tool definition
            test.verifyError(@()prodserver.mcp.internal.mcpDefinition( ...
                "undescribed", "undescribed"),"prodserver:mcp:EmptyToolDescription");

            % Unparsable file.
            test.verifyError(@()prodserver.mcp.internal.mcpDefinition( ...
                "notMATLAB", "notMATLAB"),"prodserver:mcp:CannotParseToolFcn");

            % Too many arguments blocks in the file.
            test.verifyError(@()prodserver.mcp.internal.mcpDefinition( ...
                "tooMany", "tooMany"),"prodserver:mcp:TooManyArgBlocks");

            % At least one input argument missing a description.
            test.verifyError(@()prodserver.mcp.internal.mcpDefinition( ...
                "missingInputDescription", "missingInputDescription"), ...
                "prodserver:mcp:ArgumentDescriptionMissing");

            % At least one output argument missing a description.
            test.verifyError(@()prodserver.mcp.internal.mcpDefinition( ...
                "missingOutputDescription", "missingOutputDescription"), ...
                "prodserver:mcp:ArgumentDescriptionMissing");
      
        end

    end
end