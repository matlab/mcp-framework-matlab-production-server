classdef tSchema < matlab.unittest.TestCase

% Copyright 2025-2026 The MathWorks, Inc.

    properties
        toolsFolder
    end

    methods (TestClassSetup)

        function requireToyTools(test)
            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.toolsFolder = rtt.toolFolder;
        end

    end
    
    methods(Test)
        function literalLimit(test)
        % Add user-specified properties to the generated tool schema.

            % Generate definitions for tools
            tool = "toyLiteralLimit";

            % Vanilla argument list -- tools only, no GenAI.
            td = prodserver.mcp.internal.defineForMCP(tool,tool);

            % Known result
            expected = strtrim(fileread(fullfile(test.toolsFolder,tool+".json")));
            actual = jsonencode(td.tools{1});
            test.verifyEqual(actual,expected,"tool");           
        end

        function injectDollarDefs(test)
        % The value of opts.defs must end up in the schema as the value of 
        % the top-level MCPConstants.DefsVariable property.

            % Arguments that use files to specify their JSON schema.
            tool = "toyFileSchema";

            % Read the injectable JSON -- sort of nonsense to inject it
            % into the definition of this tool, but we're just testing the
            % injection mechanism here, not any kind of real-world
            % application.
            triangle = strtrim(fileread(fullfile(test.toolsFolder,...
                "triangle.json")));
            triangle = jsondecode(triangle);
            defs.inputSchema.rURL = triangle;
            defs.outputSchema.zURL = triangle;
    
            % Generate definition.
            td = prodserver.mcp.internal.defineForMCP(tool,tool,defs={defs});
    
            % Look for defs
            test.verifyEqual(td.tools{1}.dollarDefs,defs,...
                "Defs unequal or missing");
        end

        function fileDefinition(test)
        % A file-based schema that completely overrides the automatically
        % generated schema.

            % Arguments that use files to specify their JSON schema.
            tool = "toyFileSchema";
    
            % Vanilla argument list -- tools only, no GenAI.
            td = prodserver.mcp.internal.defineForMCP(tool,tool);
    
            % Known result
            expected = strtrim(fileread(fullfile(test.toolsFolder,tool+".json")));
            actual = jsonencode(td.tools{1});
            test.verifyEqual(actual,expected,"tool");           
            
        end

        function badLiteralSchema(test)
            % Badly formatting literal JSON

            % Put the badly commented MATLAB files on the path.
            import matlab.unittest.fixtures.PathFixture
            folder = fileparts(mfilename("fullpath"));
            test.applyFixture(PathFixture(fullfile(folder,"badExamples")));

            % Generate definitions for tools
            tool = "badLiteralSchema";

            test.verifyError(@()prodserver.mcp.internal.mcpDefinition( ...
                tool,tool), "prodserver:mcp:InvalidParameterSchema");     
        end

        function badFileSchema(test)
            % Badly formatting file-based JSON

            % Put the badly commented MATLAB files on the path.
            import matlab.unittest.fixtures.PathFixture
            folder = fileparts(mfilename("fullpath"));
            test.applyFixture(PathFixture(fullfile(folder,"badExamples")));

            % Generate definitions for tools
            tool = "badFileSchema";

            test.verifyError(@()prodserver.mcp.internal.mcpDefinition( ...
                tool,tool), "prodserver:mcp:InvalidParameterSchema");   
        end

        function noSuchSchemaFile(test)
            % Badly formatting file-based JSON

            % Put the badly commented MATLAB files on the path.
            import matlab.unittest.fixtures.PathFixture
            folder = fileparts(mfilename("fullpath"));
            test.applyFixture(PathFixture(fullfile(folder,"badExamples")));

            % Generate definitions for tools
            tool = "noSuchSchemaFile";

            % prodserver:mcp:SchemaFileNotFound"
            test.verifyError(@()prodserver.mcp.internal.mcpDefinition( ...
                tool,tool), "prodserver:mcp:SchemaFileNotFound");   
        end

    end
end
