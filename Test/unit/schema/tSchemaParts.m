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

        function outputNumbersMayBeNonFinite(test)
            f = @prodserver.mcp.jsonrpc.allowNonFiniteNumbers;
            types = {"number"; "null"; "string"};
            pattern = prodserver.mcp.MCPConstants.InfTextPattern;
            isNF = @prodserver.mcp.jsonrpc.isNonFiniteNumberSchema;
            s = f(struct('type', "number", 'minimum', 0));
            test.verifyEqual(s.type, types);
            test.verifyEqual(s.pattern, pattern);
            test.verifyEqual(s.minimum, 0);
            test.verifyTrue(isNF(s));
            s = f(struct('type', "array", 'items', struct('type', "number")));
            test.verifyEqual(s.type, "array");
            test.verifyFalse(isNF(s), "an array is not a number");
            test.verifyTrue(isNF(s.items));
            s = f(struct('type', "object", 'properties', struct( ...
                'a', struct('type', "number"), 'n', struct('type', "integer"))));
            test.verifyTrue(isNF(s.properties.a));
            test.verifyEqual(s.properties.n.type, "integer", "integers can't be NaN or Inf");
            s = f(struct('anyOf', {{struct('type', "number"), struct('type', "string")}}));
            test.verifyTrue(isNF(s.anyOf{1}));
            test.verifyEqual(s.anyOf{2}.type, "string");
            % Alternatives jsondecode stacked into a struct array.
            s = f(struct('anyOf', jsondecode('[{"type":"number"},{"type":"integer"}]')));
            test.verifyTrue(isNF(s.anyOf{1}));
            test.verifyEqual(s.anyOf{2}.type, 'integer');
            % Already a list (a duration's), or a pattern of its own: unchanged.
            d = prodserver.mcp.jsonrpc.jsonTimeSchema("duration", ...
                prodserver.mcp.jsonrpc.WireShape.Scalar);
            test.verifyEqual(f(d), d);
            p = struct('type', "number", 'pattern', "x");
            test.verifyEqual(f(p), p);
        end

        function outputNumbersPublishedNonFinite(test)
            % Plain JSON outputs only, on both paths; not inputs, not the
            % invertible encoding, not a %#schema that replaces the
            % generated one.
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            isNF = @prodserver.mcp.jsonrpc.isNonFiniteNumberSchema;
            d = prodserver.mcp.internal.mcpDefinition("toyNonFinite", ...
                "toyNonFinite", encoding="JSON");
            % An example output with Inf builds: 1.7 required Invertible.
            e = prodserver.mcp.schema("toyNonFinite", @() toyNonFinite("inf"), ...
                encoding="JSON");
            for def = [d e]
                o = def.tools.outputSchema.properties;
                test.verifyTrue(isNF(o.s), jsonencode(o.s));
                test.verifyTrue(isNF(o.v.items), jsonencode(o.v));
            end
            d = prodserver.mcp.internal.mcpDefinition("toyScalarTwo", ...
                "toyScalarTwo", encoding="JSON");
            test.verifyEqual(string(d.tools.inputSchema.properties.n.type), ...
                "number", "inputs are unchanged");
            d = prodserver.mcp.internal.mcpDefinition("toyNonFinite", ...
                "toyNonFinite", encoding="Invertible");
            test.verifyFalse(contains(jsonencode(d.tools.outputSchema), ...
                """null"""), "the invertible encoding writes NaN as ""NaN""");
        end

        function injectConflictsWithScalar(test)
            import prodserver.mcp.internal.SchemaInjection
            user = struct('inject', SchemaInjection.Add, 'schema', ...
                struct('maxItems', 3));
            test.verifyError(@() prodserver.mcp.jsonrpc.injectSchema( ...
                struct('type', "number"), user, "x"), "prodserver:mcp:SchemaConflict");
        end

        function conflictSaysWhichSideDeclaredWhat(test)
            % It said "argument block declares scalar" even when the
            % %#schema's type excluded arrays and the argument block allowed
            % one.
            import prodserver.mcp.internal.SchemaInjection
            add = @(s) struct('inject', SchemaInjection.Add, 'schema', s);
            generatedArray = struct('type', "array", 'items', struct('type', "number"));
            cases = {
                struct('type', "number"), add(struct('maxItems', 3)), ...
                    "%#schema declares maxItems, for an array, but the argument block declares a scalar."
                generatedArray, add(struct('type', {{'number'; 'null'}})), ...
                    "%#schema declares the types ""number"", ""null"", which exclude arrays, but the argument block allows an array."
                generatedArray, add(struct('type', "string")), ...
                    "%#schema declares the type ""string"", which excludes arrays, but the argument block allows an array."
                struct('type', "array"), add(struct('type', "number", 'maxItems', 3)), ...
                    "%#schema declares maxItems, for an array, but also the type ""number"", which excludes arrays."
                };
            for k = 1:size(cases, 1)
                try
                    prodserver.mcp.jsonrpc.injectSchema(cases{k,1}, cases{k,2}, "x");
                    test.verifyFail("case " + k + ": expected SchemaConflict");
                catch err
                    test.verifyEqual(string(err.identifier), ...
                        "prodserver:mcp:SchemaConflict", "case " + k);
                    test.verifyEqual(string(err.message), ...
                        "Parameter 'x': " + cases{k,3} + " These are incompatible.", ...
                        "case " + k);
                end
            end
        end

        function injectUnionAndAlternativesWithSameKeywords(test)
            % jsondecode stacks alternatives with the same keywords into a
            % struct array, which nestedFieldValues walked into: "Too many
            % input arguments".
            import prodserver.mcp.internal.SchemaInjection
            user = struct('inject', SchemaInjection.Add, 'schema', ...
                jsondecode('{"anyOf": [{"type": "number"}, {"type": "string"}]}'));
            d = struct('type', "array", 'items', struct('type', "number"));
            s = prodserver.mcp.jsonrpc.injectSchema(d, user, "x", ...
                prodserver.mcp.WireEncoding.JSON);
            test.verifyFalse(isfield(s, 'type'), "the union replaces the type");
            test.verifyEqual(s.items, d.items, "array keywords stay");
            test.verifyEqual(s.anyOf, user.schema.anyOf);
            s = prodserver.mcp.jsonrpc.injectSchema(d, user, "x", ...
                prodserver.mcp.WireEncoding.Invertible);
            test.verifyEqual(s.type, "array", "the wrapper's data is an array");
            s = prodserver.mcp.jsonrpc.injectSchema(d, user, "x");
            test.verifyEqual(s.type, "array", "with no encoding, as before");
            user.schema.type = "number";
            test.verifyError(@() prodserver.mcp.jsonrpc.injectSchema(d, user, "x", ...
                prodserver.mcp.WireEncoding.JSON), "prodserver:mcp:SchemaConflict", ...
                "a union beside a type the pragma states is not replaced");
        end

        function injectTypeList(test)
            % A list of types is scalar only without "array". It used to
            % raise MATLAB:nonLogicalConditional.
            import prodserver.mcp.internal.SchemaInjection
            list = @(t) struct('inject', SchemaInjection.Add, 'schema', ...
                struct('type', {t}, 'maxItems', 3));
            s = prodserver.mcp.jsonrpc.injectSchema(struct('type', "number"), ...
                list({'array'; 'null'}), "x");
            test.verifyEqual(s.type, {'array'; 'null'});
            test.verifyError(@() prodserver.mcp.jsonrpc.injectSchema( ...
                struct('type', "number"), list({'number'; 'null'}), "x"), ...
                "prodserver:mcp:SchemaConflict");
            user = struct('inject', SchemaInjection.Replace, 'schema', ...
                struct('type', {{'number'; 'null'}}));
            s = prodserver.mcp.jsonrpc.injectSchema(struct('type', "number"), user, "x");
            test.verifyEqual(s.type, {'number'; 'null'});
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
