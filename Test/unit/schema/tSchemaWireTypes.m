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
