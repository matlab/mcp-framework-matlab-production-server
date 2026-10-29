classdef tSchemaParts < matlab.unittest.TestCase
% The pieces both schema paths -- mcpDefinition and the example path --
% build parameter schemas from.

% Copyright 2026 The MathWorks, Inc.

    properties
        Sizes   % schemaWireTimes declares (1,1), (1,:) and (1,3)
    end

    methods (TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(prodserver.mcp.test.mixin.RequireSchemaTools());
            in = prodserver.mcp.internal.metafunction("schemaWireTimes").Signature.Inputs;
            test.Sizes = arrayfun(@(p) {p.Validation.Size}, in);
        end
    end

    methods (Test)

        function injectAddsOrReplaces(test)
            import prodserver.mcp.internal.SchemaInjection
            d = struct('type', "number", 'description', "x");
            user = struct('inject', SchemaInjection.Add, 'schema', ...
                struct('minimum', 0));
            [s, replaced] = prodserver.mcp.jsonrpc.injectSchema(d, user, "x");
            test.verifyFalse(replaced);
            test.verifyEqual(s, struct('type', "number", 'description', "x", 'minimum', 0));
            user.inject = SchemaInjection.Replace;
            [s, replaced] = prodserver.mcp.jsonrpc.injectSchema(d, user, "x");
            test.verifyTrue(replaced);
            test.verifyEqual(s, struct('minimum', 0));
        end

        function injectConflictsWithScalar(test)
            import prodserver.mcp.internal.SchemaInjection
            user = struct('inject', SchemaInjection.Add, 'schema', ...
                struct('maxItems', 3));
            test.verifyError(@() prodserver.mcp.jsonrpc.injectSchema( ...
                struct('type', "number"), user, "x"), "prodserver:mcp:SchemaConflict");
        end

        function sizeShapesSchema(test)
            f = @prodserver.mcp.jsonrpc.declaredSizeSchema;
            arr = struct('type', "array", 'items', struct('type', "number"));
            % (1,1): not an array.
            test.verifyEqual(f(arr, test.Sizes{1}, "number"), struct('type', "number"));
            test.verifyEqual(f(arr, test.Sizes{1}, ""), struct('type', "array"), ...
                "No scalar type: left as it is.");
            % (1,3): exactly three. (1,:): any number.
            s = f(struct('type', "number"), test.Sizes{3}, "number");
            test.verifyEqual(s, struct('type', "array", 'items', ...
                struct('type', "number"), 'minItems', 3, 'maxItems', 3));
            s = f(struct('type', "number"), test.Sizes{2}, "number");
            test.verifyEqual(s, struct('type', "array", 'items', struct('type', "number")));
            % Several observed forms become the items' alternatives.
            s = f(struct('anyOf', {{struct('type', "number"), arr}}), test.Sizes{2}, "");
            test.verifyEqual(s.items, struct('type', "number"), ...
                "The same item form, once");
            % No size: as it is.
            test.verifyEqual(f(arr, [], "number"), arr);
        end

        function uniqueKeepsOrder(test)
            a = struct('type', "number"); b = struct('type', "string");
            test.verifyEqual(prodserver.mcp.jsonrpc.uniqueSchemas({a, b, a, b}), {a, b});
            test.verifyEqual(prodserver.mcp.jsonrpc.uniqueSchemas({}), {});
        end

        function descriptionDropsPragmasAtDefinition(test)
            lines = ["First line"; "#schema {""minimum"":0}"; "Second"];
            f = @prodserver.mcp.internal.descriptionText;
            test.verifyEqual(f(lines, prodserver.mcp.BuildStage.Definition), ...
                "First line" + newline + "Second");
            test.verifyEqual(f(lines, prodserver.mcp.BuildStage.Wrapper), ...
                strjoin(lines, newline));
        end

        function wireMessageOnce(test)
            import prodserver.mcp.MCPConstants
            f = @prodserver.mcp.jsonrpc.withWireEncodingMsg;
            test.verifyEqual(f("A number", "input"), ...
                ["A number"; MCPConstants.WireEncodingInputMsg]);
            test.verifyEqual(f("A number", "output"), ...
                ["A number"; MCPConstants.WireEncodingOutputMsg]);
            % Not twice, and not for a URL.
            once = f("A number", "input");
            test.verifyEqual(f(once, "input"), once);
            url = MCPConstants.ByReferencePrefix + " the data";
            test.verifyEqual(f(url, "input"), url);
        end

        function toolDescriptionForEncoding(test)
            import prodserver.mcp.MCPConstants
            f = @prodserver.mcp.internal.encodingDescription;
            inv = f("Adds.", prodserver.mcp.WireEncoding.Invertible);
            test.verifyEqual(inv, "Adds. " + MCPConstants.WireEncodingRequiredMsg);
            test.verifyEqual(f(inv, prodserver.mcp.WireEncoding.Invertible), inv, ...
                "Not twice");
            test.verifyEqual(f(inv, prodserver.mcp.WireEncoding.JSON), "Adds.");
        end

        function finishWrapsOrAnnotates(test)
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.WireEncoding
            f = @prodserver.mcp.jsonrpc.finishParameterSchema;
            d = struct('type', "number", 'description', "x");
            test.verifyEqual(f(d, WireEncoding.JSON, false), d);
            w = f(d, WireEncoding.Invertible, false);
            % A scalar's data is an array of one, as the encoder sends it.
            test.verifyEqual(w.properties.data, struct('type', "array", ...
                'items', struct('type', "number"), 'minItems', 1, 'maxItems', 1));
            test.verifyEqual(w.description, "x");
            c = f(d, WireEncoding.Invertible, true);
            test.verifyEqual(c.annotation, MCPConstants.InvertibleAnnotation);
            % A URL is never wrapped, and gets examples.
            u = struct('type', "string", 'description', ...
                MCPConstants.ByReferencePrefix + " the data");
            e = f(u, WireEncoding.Invertible, false);
            test.verifyEqual(e.type, "string");
            test.verifyEqual(e.examples, MCPConstants.ByReferenceExample);
        end

        function parameterObjectAndOrder(test)
            import prodserver.mcp.internal.ParameterKind
            kind = [ParameterKind.Required ParameterKind.Optional ParameterKind.NameValue];
            props = struct('a', struct('type', "number"), 'b', struct(), 'c', struct());
            s = prodserver.mcp.internal.parameterObject(props, {'a'}, kind);
            test.verifyEqual(s.type, "object");
            test.verifyEqual(s.required, {'a'});
            [lo, hi] = ParameterKind.NargRange(kind);
            test.verifyEqual([s.minProperties s.maxProperties], [lo hi]);
            test.verifyEqual(prodserver.mcp.internal.parameterObject(struct(), {}, ...
                ParameterKind.empty), struct('type', "object"));
            test.verifyEqual(ParameterKind.PositionalOrder({'a', 'b', 'c'}, kind), ...
                ["a" "b"]);
        end

        function examplePathEncodingMessageOnce(test)
            % A description that already names the encoding resource isn't
            % given the message again, on either path.
            import prodserver.mcp.MCPConstants
            defs = prodserver.mcp.schema("schemaWireTimes", ...
                @() schemaWireTimes(datetime(2026,1,1), datetime(2026,1,1:2), ...
                hours([1 2 3])), encoding="Invertible");
            d = defs.tools.description;
            test.verifyEqual(count(d, MCPConstants.WireEncodingResourceURI), 1);
        end

    end
end
