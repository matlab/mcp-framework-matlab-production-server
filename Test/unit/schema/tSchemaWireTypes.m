classdef tSchemaWireTypes < matlab.unittest.TestCase
%tSchemaWireTypes Verify schemas for classes JSON can't describe.
%   Only the invertible encoding carries datetime, duration, categorical,
%   table and timetable; no encoding carries function handles, maps or
%   calendar durations. Declared and observed parameters must agree: build
%   errors where the encoding can't carry the class, and otherwise a
%   schema that matches the encoding in wire_encoding_rules.txt.

% Copyright 2026 The MathWorks, Inc.

    methods(TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods(Test)

        % Classification

        function supportByClass(test)
            import prodserver.mcp.jsonrpc.WireSupport
            support = @WireSupport.of;
            test.verifyEqual(support("double"), WireSupport.JSON);
            test.verifyEqual(support("single"), WireSupport.JSON);
            test.verifyEqual(support("cell"), WireSupport.JSON);
            test.verifyEqual(support("table"), WireSupport.Invertible);
            test.verifyEqual(support("datetime"), WireSupport.Converted);
            test.verifyEqual(support("duration"), WireSupport.Converted);
            test.verifyEqual(support("categorical"), WireSupport.Invertible);
            test.verifyEqual(support("function_handle"), WireSupport.None);
            test.verifyEqual(support("containers.Map"), WireSupport.None);
            test.verifyEqual(support("calendarDuration"), WireSupport.None);
            test.verifyEqual(support("table", struct('table', "object")), ...
                WireSupport.JSON, "A typemap entry makes a class JSON.");
        end

        % Declared parameters

        function declaredInvertibleOnlyRejectedUnderJSON(test)
            test.verifyError(@() prodserver.mcp.internal.mcpDefinition( ...
                "schemaWireDeclared", "schemaWireDeclared", encoding="JSON"), ...
                "prodserver:mcp:IncompatibleArgumentType");
        end

        function declaredUnsupportedRejected(test)
            for enc = ["JSON", "Invertible"]
                test.verifyError(@() prodserver.mcp.internal.mcpDefinition( ...
                    "schemaWireHandle", "schemaWireHandle", encoding=enc), ...
                    "prodserver:mcp:IncompatibleArgumentType", enc);
                test.verifyError(@() prodserver.mcp.internal.mcpDefinition( ...
                    "schemaWireCalendar", "schemaWireCalendar", encoding=enc), ...
                    "prodserver:mcp:IncompatibleArgumentType", enc);
            end
        end

        function declaredInvertibleSchemas(test)
            defs = prodserver.mcp.internal.mcpDefinition( ...
                "schemaWireDeclared", "schemaWireDeclared", ...
                encoding="Invertible");
            p = defs.tools.inputSchema.properties;

            verifyTabular(test, p.t, "table", ["type","variables"]);
            verifyTabular(test, p.tt, "timetable", ...
                ["type","rowTimes","variables"]);
            % (1,1) datetime is a bare ISO 8601 string, or the wrapper
            % with tz when it has a named zone.
            verifyScalarDatetime(test, p.d1);
            % (1,:) datetime may hold one element: the same forms.
            verifyScalarDatetime(test, p.dn);
            % (1,1) duration is the type and seconds form.
            test.verifyEqual(string(p.du.properties.type.enum), "duration");
            test.verifyEqual(string(p.du.required(:))', ["type","seconds"]);
            % (1,3) duration is always the wrapped form.
            verifyWrapped(test, p.d3, "duration");
            verifyWrapped(test, p.c, "categorical");

            % Each is the whole encoded value: no envelope around it.
            for n = string(fieldnames(p))'
                test.verifyFalse(prodserver.mcp.jsonrpc.isGenericWrapper(p.(n)), ...
                    n + " must not be wrapped in the generic envelope.");
            end

            % The signature keeps the MATLAB classes.
            sig = defs.signatures.schemaWireDeclared.input;
            test.verifyEqual(sig.type(sig.name == "t"), "table");
            test.verifyEqual(sig.type(sig.name == "d1"), "datetime");
        end

        function declaredInvertibleOutputs(test)
            defs = prodserver.mcp.internal.mcpDefinition( ...
                "schemaWireOutputs", "schemaWireOutputs", ...
                encoding="Invertible");
            p = defs.tools.outputSchema.properties;
            verifyTabular(test, p.t, "table", ["type","variables"]);
            verifyScalarDatetime(test, p.d1);
            verifyScalarDatetime(test, p.dn);
        end

        % Observed parameters

        function observedUnsupportedRejected(test)
            values = {@sin, containers.Map({'a'}, {1}), calmonths(2)};
            for k = 1:numel(values)
                for enc = ["JSON", "Invertible"]
                    test.verifyError(@() observe(values{k}, enc), ...
                        "prodserver:mcp:IncompatibleArgumentType", ...
                        class(values{k}) + " " + enc);
                end
            end
        end

        function observedInvertibleOnlyRejectedUnderJSON(test)
            values = {table([1;2]), categorical("a"), timetable(seconds(1), 1)};
            for k = 1:numel(values)
                test.verifyError(@() observe(values{k}, "JSON"), ...
                    "prodserver:mcp:IncompatibleArgumentType", ...
                    class(values{k}));
            end
        end

        function observedComplexRejectedUnderJSON(test)
            % A complex value's class is a JSON number's, but plain JSON
            % has no form for its imaginary part.
            values = {1+2i, [1+2i 3-4i], single(1i), int8(complex(1,2))};
            labels = ["complex double", "complex array", "complex single", ...
                "complex int8"];
            for k = 1:numel(values)
                test.verifyError(@() observe(values{k}, "JSON"), ...
                    "prodserver:mcp:IncompatibleArgumentType", labels(k));
            end
        end

        function observedNestedComplexNamesPath(test)
            try
                observe(struct('a', 1, 'z', 2i), "JSON");
                test.verifyFail("Expected IncompatibleArgumentType.");
            catch me
                test.verifyEqual(me.identifier, ...
                    'prodserver:mcp:IncompatibleArgumentType');
                test.verifySubstring(me.message, "'x.z'");
            end
            test.verifyError(@() observe({1, 2i}, "JSON"), ...
                "prodserver:mcp:IncompatibleArgumentType", "in a cell");
        end

        function observedComplexUnderInvertible(test)
            % The schema of a real value, and nothing of the observer's
            % own left in it.
            complexSchema = observe(1+2i, "Invertible");
            test.verifyEqual(complexSchema, observe(3, "Invertible"));
            test.verifyFalse(contains(jsonencode(observe(struct('z', 2i), ...
                "Invertible")), prodserver.mcp.internal.Constants.ComplexTag), ...
                "in a struct field");

            % Complex and real examples: one schema, as for real alone.
            defs = prodserver.mcp.schema("schemaWireAny", ...
                {@() schemaWireAny(1+2i), @() schemaWireAny(3)}, ...
                encoding="Invertible");
            test.verifyEqual(defs.tools.inputSchema.properties.x, ...
                observe(3, "Invertible"));
        end

        function observedInfiniteRejectedUnderJSON(test)
            % Plain JSON writes Inf as null, which reads back as NaN.
            values = {Inf, [1 -Inf], single(Inf), {1, Inf}};
            labels = ["scalar", "array", "single", "in a cell"];
            for k = 1:numel(values)
                test.verifyError(@() observe(values{k}, "JSON"), ...
                    "prodserver:mcp:IncompatibleArgumentType", labels(k));
            end
            try
                observe(struct('a', 1, 'z', -Inf), "JSON");
                test.verifyFail("Expected IncompatibleArgumentType.");
            catch me
                test.verifySubstring(me.message, "'x.z'");
                test.verifySubstring(me.message, "Inf or -Inf");
            end
            % NaN alone is a number plain JSON carries in an array.
            test.verifyEqual(observe([1 NaN], "JSON"), observe([1 2], "JSON"));
        end

        function observedInfiniteOutputUnderJSON(test)
            % An output's Inf is sent as text, which its schema allows (see
            % allowNonFiniteNumbers): a division by zero no longer needs the
            % invertible encoding. A cell's elements have no schema of
            % their own, so Inf in a cell is still refused, as it is at
            % run time.
            isNF = @prodserver.mcp.jsonrpc.isNonFiniteNumberSchema;
            % schemaWireEcho(k) returns the k-th of Inf, single(-Inf),
            % [1 -Inf], a struct with a field -Inf and {1, Inf}, from a
            % finite argument.
            test.verifyTrue(isNF(observeOutput(1)), "scalar");
            test.verifyTrue(isNF(observeOutput(2)), "single");
            p = observeOutput(3);
            test.verifyTrue(isNF(p.items), "array");
            p = observeOutput(4);
            test.verifyTrue(isNF(p.properties.z), "struct field");
            test.verifyError(@() observeOutput(5), ...
                "prodserver:mcp:IncompatibleArgumentType", "in a cell");
            % (An infinite duration, seconds(Inf), isn't tagged: build
            % can't see it, and the tool's call fails, as before.)

            % Examples in both shapes: an alternative of each, both
            % allowing the text, and the value is sent in the one its
            % shape fits.
            defs = prodserver.mcp.schema("schemaWireEcho", ...
                @() [schemaWireEcho(1) schemaWireEcho(3)], encoding="JSON");
            y = defs.tools.outputSchema.properties.y;
            alts = prodserver.mcp.jsonrpc.schemaAlternatives(y);
            test.verifyNumElements(alts, 2);
            test.verifyTrue(any(cellfun(isNF, alts)), "the scalar");
            test.verifyTrue(any(cellfun(@(a) isfield(a, 'items') && ...
                isNF(a.items), alts)), "the array");
            P = @(v) string(jsonencode(struct('y', ...
                {prodserver.mcp.jsonrpc.plainJSONValue(v, y)})));
            test.verifyEqual(P(Inf), "{""y"":""Inf""}");
            test.verifyEqual(P([1 -Inf]), "{""y"":[1,""-Inf""]}");
        end

        function observedFieldTextAndInfRejected(test)
            % Examples whose struct field is Inf in one and text in
            % another: a struct fits both alternatives, so the field may be
            % either, and the text "Inf" would read back as text. Stopped at
            % build, as for the output itself; it used to fail at run time.
            try
                prodserver.mcp.schema("schemaStructEcho", ...
                    @() {schemaStructEcho(6), schemaStructEcho(7)}, ...
                    encoding="JSON");
                test.verifyFail("Expected IncompatibleArgumentType.");
            catch me
                test.verifyEqual(me.identifier, ...
                    'prodserver:mcp:IncompatibleArgumentType');
                test.verifySubstring(me.message, "y.a");
            end
            % Under the invertible encoding, Inf and text are told apart.
            test.verifyWarningFree(@() prodserver.mcp.schema("schemaStructEcho", ...
                @() {schemaStructEcho(6), schemaStructEcho(7)}, ...
                encoding="Invertible"));
        end

        function observedStructsWithDifferentFields(test)
            % Examples that returned structs with different fields, or of
            % different shapes: an alternative for each. Each field is sent
            % by the schemas any of them gives it, and read back by them, so
            % an Inf in a field only one describes is text, and arrives as
            % Inf. It was a tool error, or arrived as text.
            echo = @(ks) prodserver.mcp.schema("schemaStructEcho", ...
                @() arrayfun(@(k) schemaStructEcho(k), ks, UniformOutput=false), ...
                encoding="JSON");
            values = {struct('a', {1, -Inf}, 'b', {Inf, 4}), ...
                struct('a', Inf, 'b', 2), struct('a', 1, 'b', -Inf), ...
                struct('a', {Inf, 2})};
            for ks = {[1 2], [3 4], [1 4], [2 3]}
                d = echo(ks{1});
                test.verifyTrue(isfield(d.tools.outputSchema.properties.y, 'anyOf'), ...
                    mat2str(ks{1}));
                for k = 1:numel(values)
                    v = values{k};
                    test.verifyEqual(roundTrip(d, v), v, ...
                        mat2str(ks{1}) + " " + k);
                end
            end
            % Examples with fields a and b, and a field a that is empty:
            % anyOf [{a, b required}, {a: array}]. A struct with a only is
            % the second's, so its a is an array: it was {"a":7}, which
            % matched neither.
            d = echo([4 5]);
            j = jsonencode(struct('y', {prodserver.mcp.jsonrpc.plainJSONValue( ...
                struct('a', 7), d.tools.outputSchema.properties.y)}));
            test.verifyEqual(j, '{"y":{"a":[7]}}');
            test.verifyEqual(roundTrip(d, struct('a', 7)), struct('a', 7));
            test.verifyEqual(roundTrip(d, struct('a', 1, 'b', 2)), struct('a', 1, 'b', 2));
            % Examples giving anyOf [array of {a}, {a, b required}]: a
            % struct with a only is the array's, [{"a":7}]. It was sent as
            % {"a":7}, which matched neither.
            d = echo([1 4]);
            j = jsonencode(struct('y', {prodserver.mcp.jsonrpc.plainJSONValue( ...
                struct('a', 7), d.tools.outputSchema.properties.y)}));
            test.verifyEqual(j, '{"y":[{"a":7}]}');
            test.verifyEqual(roundTrip(d, struct('a', 7)), struct('a', 7));
            test.verifyEqual(roundTrip(d, struct('a', 1, 'b', 2)), struct('a', 1, 'b', 2));
            % A field empty in one example and a number in another: either
            % reads back. ([] would have been an error: the first
            % alternative's field is one number.)
            d = echo([3 5]);
            test.verifyEqual(roundTrip(d, struct('a', [])), struct('a', []));
            test.verifyEqual(roundTrip(d, struct('a', NaN)), struct('a', NaN));
            test.verifyEqual(roundTrip(d, struct('a', Inf)), struct('a', Inf));
        end

        function observedInfiniteBesideText(test)
            % Examples that returned text and Inf: a client would read the
            % text "Inf" as text, so build stops, as for an argument's Inf.
            % schemaWireEcho(6) returns 'none', (7) "none", (8) [1 2] and
            % (9) ["a" "b"].
            echo = @(ks) prodserver.mcp.schema("schemaWireEcho", ...
                @() arrayfun(@(k) schemaWireEcho(k), ks, UniformOutput=false), ...
                encoding="JSON");
            for ks = {[1 6], [7 2], [6 1 3]}
                test.verifyError(@() echo(ks{1}), ...
                    "prodserver:mcp:IncompatibleArgumentType", mat2str(ks{1}));
            end
            % It names the output as one, not as a parameter.
            try
                echo([1 6]);
            catch err
                test.verifySubstring(err.message, "Output 'y' is text");
            end
            % Inf only in an array, [1,"-Inf"], or text only in one: no
            % call is ambiguous at build.
            for ks = {[6 3], [9 3], [9 1], [8 6]}
                d = echo(ks{1});
                test.verifyTrue(isfield(d.tools.outputSchema.properties, 'y'), ...
                    mat2str(ks{1}));
            end
            % Under the invertible encoding, the wrapper tells them apart.
            d = prodserver.mcp.schema("schemaWireEcho", ...
                @() arrayfun(@(k) schemaWireEcho(k), [1 6], UniformOutput=false), ...
                encoding="Invertible");
            test.verifyTrue(isfield(d.tools.outputSchema.properties, 'y'));
        end

        function observedInfiniteUnderInvertible(test)
            % The schema of a finite value, and no tag left in it.
            test.verifyEqual(observe([1 Inf], "Invertible"), ...
                observe([1 2], "Invertible"));
            test.verifyFalse(contains(jsonencode(observe(struct('z', Inf), ...
                "Invertible")), prodserver.mcp.internal.Constants.InfiniteTag), ...
                "in a struct field");
            % Infinite and finite examples: one schema.
            defs = prodserver.mcp.schema("schemaWireAny", ...
                {@() schemaWireAny(Inf), @() schemaWireAny(3)}, ...
                encoding="Invertible");
            test.verifyEqual(defs.tools.inputSchema.properties.x, ...
                observe(3, "Invertible"));
        end

        function observedTimesUnderJSON(test)
            % JSON carries a datetime as ISO 8601 text and a duration as
            % seconds, so they build, with schemas that say so.
            p = observe(datetime(2026,1,1), "JSON");
            test.verifyEqual(string(p.type), ["string"; "null"]);
            test.verifyEqual(p.format, "date-time");

            p = observe(datetime(2026,1,1:3), "JSON");
            test.verifyEqual(p.type, "array");
            test.verifyEqual(p.items.format, "date-time");

            p = observe(minutes(5), "JSON");
            test.verifyEqual(string(p.type), ["number"; "null"]);
            test.verifyEqual(p.(prodserver.mcp.MCPConstants.MatlabClass_Field), ...
                "duration");

            p = observe(struct('when', datetime(2026,1,1)), "JSON");
            test.verifyEqual(p.properties.when.format, "date-time", ...
                "in a struct field");
        end

        function declaredTimesUnderJSON(test)
            defs = prodserver.mcp.internal.mcpDefinition( ...
                "schemaWireTimes", "schemaWireTimes", encoding="JSON");
            p = defs.tools.inputSchema.properties;
            test.verifyEqual(p.d1.format, "date-time", "(1,1) datetime");
            test.verifyEqual(p.dn.type, "array", "(1,:) datetime");
            test.verifyEqual(p.dn.items.format, "date-time");
            test.verifyEqual(p.d3.minItems, 3, "(1,3) duration");
            test.verifyEqual(p.d3.items.(prodserver.mcp.MCPConstants.MatlabClass_Field), ...
                "duration");
            o = defs.tools.outputSchema.properties;
            test.verifyEqual(o.later.format, "date-time", "a datetime output");
            sig = defs.signatures.schemaWireTimes.input;
            test.verifyEqual(sig.type(sig.name == "d1"), "datetime");
        end

        function observedNestedUnsupportedNamesPath(test)
            % A function handle in a struct field.
            try
                observe(struct('a', 1, 'f', @sin), "JSON");
                test.verifyFail("Expected IncompatibleArgumentType.");
            catch me
                test.verifyEqual(me.identifier, ...
                    'prodserver:mcp:IncompatibleArgumentType');
                test.verifySubstring(me.message, "'x.f'");
            end
            % A map in a cell.
            test.verifyError(@() observe({1, containers.Map({'a'}, {1})}, ...
                "Invertible"), "prodserver:mcp:IncompatibleArgumentType");
        end

        function observedInvertibleSchemas(test)
            p = observe(table([1;2]), "Invertible");
            verifyTabular(test, p, "table", ["type","variables"]);
            test.verifyTrue(contains(p.annotation, "Invertible wire encoding"));

            p = observe(datetime(2026,1,1), "Invertible");
            verifyScalarDatetime(test, p);

            p = observe(datetime(2026,1,1:3), "Invertible");
            verifyWrapped(test, p, "datetime");

            p = observe(minutes(5), "Invertible");
            test.verifyEqual(string(p.properties.type.enum), "duration");
        end

        function observedBothShapesGiveEither(test)
            defs = prodserver.mcp.schema("schemaWireAny", ...
                {@() schemaWireAny(datetime(2026,1,1)), ...
                 @() schemaWireAny(datetime(2026,1,1:3))}, ...
                encoding="Invertible");
            p = defs.tools.inputSchema.properties.x;
            verifyScalarDatetime(test, p);
        end

        function observedNestedInvertible(test)
            % A table in a struct field gets the table schema.
            p = observe(struct('t', table([1;2])), "Invertible");
            [~, data] = prodserver.mcp.test.wrapperOf(p);
            verifyTabular(test, data.properties.t, "table", ["type","variables"]);
        end

        function observedCellIsArray(test)
            p = observe({1, 'a'}, "JSON");
            test.verifyEqual(p.type, "array");
            test.verifyFalse(isfield(p, prodserver.mcp.internal.Constants.ElementsTag));
        end

        function observedTypemapApplies(test)
            defs = prodserver.mcp.schema("schemaWireAny", ...
                @() schemaWireAny(table([1;2])), encoding="JSON", ...
                typemap=struct('table', "object"));
            test.verifyEqual(defs.tools.inputSchema.properties.x.type, "object");
        end

        % Shared pieces

        function shapeFromSize(test)
            % schemaWireTimes declares (1,1), (1,:) and (1,3).
            import prodserver.mcp.jsonrpc.WireShape
            in = prodserver.mcp.internal.metafunction("schemaWireTimes").Signature.Inputs;
            test.verifyEqual(WireShape.fromSize([]), WireShape.Either);
            test.verifyEqual(WireShape.fromSize(in(1).Validation.Size), WireShape.Scalar);
            test.verifyEqual(WireShape.fromSize(in(2).Validation.Size), WireShape.Either);
            test.verifyEqual(WireShape.fromSize(in(3).Validation.Size), WireShape.Array);
        end

        function templateCarriesAnnotation(test)
            % Every Invertible schema is recognised by this text.
            t = jsondecode(prodserver.mcp.internal.readUTF8(fullfile( ...
                prodserver.mcp.internal.packageFolder(), "+prodserver", ...
                "+mcp", "+jsonrpc", "wireEncodingArgTemplate.json")));
            test.verifyEqual(string(t.annotation), ...
                prodserver.mcp.MCPConstants.InvertibleAnnotation);
        end

        function wrapperAlternatives(test)
            % The published schema and the validator accept the same forms.
            w = prodserver.mcp.jsonrpc.wrapInvertible( ...
                struct('type', "array", 'items', struct('type', "number"), ...
                'description', "Some numbers"));
            test.verifyTrue(prodserver.mcp.jsonrpc.isGenericWrapper(w));
            test.verifyEqual(w.description, "Some numbers");
            [bare, wrapped] = prodserver.mcp.jsonrpc.wrapperAlternatives(w);
            test.verifyEqual(bare{1}.type, "number");
            test.verifyEqual(string(bare{2}.enum(:))', ["NaN" "Inf" "-Inf"]);
            test.verifyFalse(isfield(wrapped, 'description'));
            test.verifyFalse(isfield(wrapped, 'annotation'));
            % NaN among the data, too.
            v = struct('type', "double", 'size', [1 2], 'data', {{1, "NaN"}});
            detail = prodserver.mcp.validation.validateArgumentsWithSchema( ...
                struct('properties', struct('x', wrapped)), "x", {v});
            test.verifyEqual(detail, "");
            % A schema of wireTypeSchema's lists its own forms.
            test.verifyFalse(prodserver.mcp.jsonrpc.isGenericWrapper( ...
                prodserver.mcp.jsonrpc.wireTypeSchema("table")));
        end

        function validatorReturnsDetail(test)
            schema = struct('properties', struct('n', struct('type', "number")));
            detail = prodserver.mcp.validation.validateArgumentsWithSchema( ...
                schema, "n", {"three"});
            test.verifyGreaterThan(strlength(detail), 0);
            test.verifyFalse(contains(detail, "failed validation"));
            test.verifyError(@() prodserver.mcp.validation. ...
                validateArgumentsWithSchema(schema, "n", {"three"}), ...
                "prodserver:mcp:SchemaValidationFailed");
        end

    end
end

function p = observe(value, encoding)
    defs = prodserver.mcp.schema("schemaWireAny", ...
        @() schemaWireAny(value), encoding=encoding);
    p = defs.tools.inputSchema.properties.x;
end

function back = roundTrip(d, v)
% V, the output y of the tool D defines, as a client reads it back: sent as
% the server sends it, decoded by its outputSchema. A vector of structs
% comes back as a column, as jsondecode gives one.
    os = d.tools.outputSchema;
    j = jsonencode(struct('y', ...
        {prodserver.mcp.jsonrpc.plainJSONValue(v, os.properties.y)}));
    b = prodserver.mcp.jsonrpc.decodeJSONValues(os, jsondecode(j), "Output");
    back = reshape(b.y, size(v));
end

function p = observeOutput(k)
% The output schema schemaWireEcho, returning its K-th value, has under
% plain JSON.
    defs = prodserver.mcp.schema("schemaWireEcho", ...
        @() schemaWireEcho(k), encoding="JSON");
    p = defs.tools.outputSchema.properties.y;
end

function verifyTabular(test, p, matlabClass, required)
    test.verifyEqual(p.type, "object");
    test.verifyEqual(string(p.properties.type.enum), matlabClass);
    test.verifyEqual(string(p.required(:))', required);
    test.verifyTrue(isfield(p.properties, 'variables'));
    test.verifyFalse(isfield(p.properties, 'data'), ...
        matlabClass + " has no data field.");
end

function verifyScalarDatetime(test, p)
% ISO 8601 text, NaT, or the wrapper with tz.
    test.verifyNumElements(p.anyOf, 3);
    test.verifyEqual(p.anyOf{1}, struct('type', "string", 'format', "date-time"));
    test.verifyEqual(string(p.anyOf{2}.enum), "NaT");
    verifyWrapped(test, p.anyOf{3}, "datetime");
    test.verifyTrue(isfield(p.anyOf{3}.properties, 'tz'));
end

function verifyWrapped(test, p, matlabClass)
    test.verifyEqual(string(p.properties.type.enum), matlabClass);
    test.verifyEqual(string(p.required(:))', ["type","size","data"]);
    test.verifyEqual(p.properties.data.type, "array");
end
