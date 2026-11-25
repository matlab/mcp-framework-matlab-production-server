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

            % Vanilla argument list.
            td = prodserver.mcp.internal.defineForMCP(tool,tool, ...
                encoding="Invertible");

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
            test.verifyEqual(td.tools{1}.inputSchema.dollarDefs,defs,...
                "Defs unequal or missing");
        end

        function fileDefinition(test)
        % A file-based schema that completely overrides the automatically
        % generated schema.

            % Arguments that use files to specify their JSON schema.
            tool = "toyFileSchema";

            % Vanilla argument list.
            td = prodserver.mcp.internal.defineForMCP(tool,tool, ...
                encoding="Invertible");
    
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

        function badPatternSchema(test)
            % A pattern MATLAB's regexp would match nothing with: build
            % stops, naming the parameter, rather than publish a tool
            % every call to which is rejected.
            import matlab.unittest.fixtures.PathFixture
            folder = fileparts(mfilename("fullpath"));
            test.applyFixture(PathFixture(fullfile(folder,"badExamples")));

            tool = "badPatternSchema";
            try
                prodserver.mcp.internal.mcpDefinition(tool, tool);
                test.verifyFail("build should have stopped");
            catch err
                test.verifyEqual(string(err.identifier), ...
                    "prodserver:mcp:InvalidParameterSchema");
                test.verifySubstring(err.message, "parameter 'x'");
                test.verifySubstring(err.message, "\p{L}");
            end
        end

        function badKeywordSchema(test)
            % A maxLength of null: build stops, naming the parameter and
            % the keyword, rather than publish a tool every call to which
            % raised an error.
            import matlab.unittest.fixtures.PathFixture
            folder = fileparts(mfilename("fullpath"));
            test.applyFixture(PathFixture(fullfile(folder,"badExamples")));

            tool = "badKeywordSchema";
            try
                prodserver.mcp.internal.mcpDefinition(tool, tool);
                test.verifyFail("build should have stopped");
            catch err
                test.verifyEqual(string(err.identifier), ...
                    "prodserver:mcp:InvalidParameterSchema");
                test.verifySubstring(err.message, "parameter 'x'");
                test.verifySubstring(err.message, ...
                    "maxLength must be a non-negative integer, not null");
            end
        end

        function schemaWithoutSingleTypeUsedAsGiven(test)
            % A union, or a list of types, is valid JSON Schema, and was an
            % internal error. Under plain JSON it is published as given:
            % there is no single type to reconcile with the declaration.
            import matlab.unittest.fixtures.PathFixture
            folder = fileparts(mfilename("fullpath"));
            test.applyFixture(PathFixture(fullfile(folder,"badExamples")));

            d = prodserver.mcp.internal.mcpDefinition("badReplaceNoType", ...
                "badReplaceNoType", encoding="JSON");
            x = d.tools.inputSchema.properties.x;
            test.verifyFalse(isfield(x, 'type'));
            test.verifyEqual(numel(x.oneOf), 2);
            f = @(v) prodserver.mcp.validation.toolArgumentError(d.tools, ...
                struct('x', v), prodserver.mcp.WireEncoding.JSON);
            test.verifyEqual(f(7), "");
            test.verifyEqual(f([1; 2]), "");
            test.verifyGreaterThan(strlength(f("seven")), 0);

            for tool = ["badReplaceTypeList" "badAddTypeList"]
                d = prodserver.mcp.internal.mcpDefinition(tool, tool, encoding="JSON");
                x = d.tools.inputSchema.properties.x;
                test.verifyEqual(string(x.type(:))', ["number" "null"], tool);
            end

            % A list for an array's items too: it was an internal error.
            d = prodserver.mcp.internal.mcpDefinition("badItemsTypeList", ...
                "badItemsTypeList", encoding="JSON");
            x = d.tools.inputSchema.properties.x;
            test.verifyEqual(string(x.type), "array");
            test.verifyEqual(string(x.items.type(:))', ["number" "null"]);
        end

        function addedUnionReplacesTheGeneratedType(test)
            % Beside "type": "array", a oneOf of a number and an array still
            % refuses a number under JSON Schema. The generated keywords for
            % arrays stay: they constrain only arrays.
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            d = prodserver.mcp.internal.mcpDefinition("toyTotal", "toyTotal", ...
                encoding="JSON");
            x = d.tools.inputSchema.properties.x;
            test.verifyFalse(isfield(x, 'type'), jsonencode(x));
            test.verifyEqual(string(x.items.type), "number", "a JSON type, not double");
            test.verifyTrue(isfield(x, 'oneOf'));
            e = prodserver.mcp.schema("toyTotal", @() toyTotal(7), encoding="JSON");
            test.verifyFalse(isfield(e.tools.inputSchema.properties.x, 'type'), ...
                "the example path too");
            % The invertible encoding describes the wrapper's data, an array.
            d = prodserver.mcp.internal.mcpDefinition("toyTotal", "toyTotal", ...
                encoding="Invertible");
            [~, data] = prodserver.mcp.test.wrapperOf(d.tools.inputSchema.properties.x);
            test.verifyEqual(string(data.type), "array");
        end

        function schemaWithoutSingleTypeUnderInvertible(test)
            % The schema describes the elements of the wrapper's data, which
            % need one type: build stops, and says why.
            import matlab.unittest.fixtures.PathFixture
            folder = fileparts(mfilename("fullpath"));
            test.applyFixture(PathFixture(fullfile(folder,"badExamples")));

            cases = {"badReplaceNoType",   "this one has none."
                     "badReplaceTypeList", "this one lists ""number"", ""null""."
                     "badAddTypeList",     "this one lists ""number"", ""null""."
                     "badItemsTypeList",   "this one lists ""number"", ""null"" for its items."};
            for k = 1:size(cases, 1)
                tool = cases{k,1};
                try
                    prodserver.mcp.internal.mcpDefinition(tool, tool, ...
                        encoding="Invertible");
                    test.verifyFail(tool + ": build should have stopped");
                catch err
                    test.verifyEqual(string(err.identifier), ...
                        "prodserver:mcp:InvalidParameterSchema", tool);
                    test.verifySubstring(err.message, ...
                        "Invalid schema for parameter 'x': under encoding=""Invertible""", tool);
                    test.verifySubstring(err.message, cases{k,2}, tool);
                    test.verifySubstring(err.message, ...
                        "or build the tool with encoding=""JSON""", tool);
                end
            end
        end

        function classSchemasNeedNoSingleType(test)
            % A datetime's or a duration's schema is the whole encoded
            % value, a union of its forms, not a wrapper's data: a %#schema
            % that only annotates it is no error.
            test.applyFixture(prodserver.mcp.test.mixin.RequireSchemaTools());
            for enc = ["JSON" "Invertible"]
                d = prodserver.mcp.internal.mcpDefinition("schemaTimeNotes", ...
                    "schemaTimeNotes", encoding=enc);
                p = d.tools.inputSchema.properties;
                test.verifyEqual(string(p.t.title), "Start", enc);
                test.verifyEqual(string(p.d.title), "Length", enc);
            end
        end

        function exampleSchemasWithoutSingleType(test)
            % With example calls, the schema's types come from the calls,
            % so a %#schema needs no type, and may list several.
            import matlab.unittest.fixtures.PathFixture
            folder = fileparts(mfilename("fullpath"));
            test.applyFixture(PathFixture(fullfile(folder,"badExamples")));

            for tool = ["badReplaceNoType" "badReplaceTypeList" "badAddTypeList"]
                for enc = ["JSON" "Invertible"]
                    d = prodserver.mcp.schema(tool, @() feval(tool, 1), ...
                        encoding=enc);
                    test.verifyTrue(isfield(d.tools.inputSchema.properties, ...
                        'x'), tool + " " + enc);
                end
            end
            d = prodserver.mcp.schema("badReplaceTypeList", ...
                @() badReplaceTypeList(1), encoding="JSON");
            x = d.tools.inputSchema.properties.x;
            test.verifyEqual(string(x.type(:))', ["number" "null"]);
            f = @(v) prodserver.mcp.validation.toolArgumentError(d.tools, ...
                struct('x', v), prodserver.mcp.WireEncoding.JSON);
            test.verifyEqual(f(3), "");
            test.verifyEqual(f([]), "");
            test.verifyGreaterThan(strlength(f("three")), 0);
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
