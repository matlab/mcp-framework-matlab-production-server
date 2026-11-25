classdef tBareForms < matlab.unittest.TestCase
% Under the invertible encoding, a parameter that may be a scalar is
% published with the bare forms wire_encoding_rules.txt allows -- 3.14,
% true, "hello" -- beside the wrapper, on both schema paths and for inputs
% and outputs alike. A fixed size of more than one element is never a
% scalar, so it keeps the wrapper alone.

% Copyright 2026 The MathWorks, Inc.

    methods (TestClassSetup)
        function requireTools(test)
            test.applyFixture(prodserver.mcp.test.mixin.RequireSchemaTools());
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
        end
    end

    methods (Test)

        function byShape(test)
            % toySingleHalf: x (1,1), xs (1,:) in; r (1,1), v (1,:) out.
            % schemaWireTimes has d3 (1,3) duration: a whole-value schema.
            d = prodserver.mcp.internal.mcpDefinition("toySingleHalf", ...
                "toySingleHalf", encoding="Invertible");
            f = @prodserver.mcp.jsonrpc.bareOrWrapped;
            test.verifyTrue(f(d.tools.inputSchema.properties.x), "(1,1)");
            test.verifyTrue(f(d.tools.inputSchema.properties.xs), "(1,:)");
            test.verifyTrue(f(d.tools.outputSchema.properties.r), "(1,1) output");
            % Description and annotation stay at the top.
            x = d.tools.inputSchema.properties.x;
            test.verifyTrue(isfield(x, 'description'));
            test.verifyTrue(prodserver.mcp.jsonrpc.isInvertibleSchema(x));
            % The bare forms: a number, or NaN/Inf/-Inf.
            [~, bare] = f(x);
            test.verifyEqual(bare{1}, struct('type', "number"));
            test.verifyEqual(string(bare{2}.enum(:))', ["NaN" "Inf" "-Inf"]);
        end

        function fixedArraysStayWrapped(test)
            % A (2,3) double is never a scalar.
            d = prodserver.mcp.internal.mcpDefinition("schemaTextCell", ...
                "schemaTextCell", encoding="Invertible");
            m = d.tools.inputSchema.properties.m;   % (2,3) char
            test.verifyTrue(prodserver.mcp.jsonrpc.isGenericWrapper(m));
            test.verifyFalse(prodserver.mcp.jsonrpc.bareOrWrapped(m));
        end

        function examplePathAndNone(test)
            % The example path forces wrapper="None": the schema itself
            % must say a bare value is allowed.
            defs = prodserver.mcp.schema("toyScalarOne", @() toyScalarOne(3), ...
                encoding="Invertible");
            test.verifyTrue(prodserver.mcp.jsonrpc.bareOrWrapped( ...
                defs.tools.inputSchema.properties.x));
            test.verifyTrue(prodserver.mcp.jsonrpc.bareOrWrapped( ...
                defs.tools.outputSchema.properties.y), "Scalar outputs go out bare");
        end

        function jsonUnchanged(test)
            % Plain JSON has no wrapper, so no change.
            d = prodserver.mcp.internal.mcpDefinition("toySingleHalf", ...
                "toySingleHalf", encoding="JSON");
            test.verifyEqual(d.tools.inputSchema.properties.x.type, "number");
            test.verifyFalse(isfield(d.tools.inputSchema.properties.x, 'anyOf'));
        end

        function bareAndWrappedValidate(test)
            % Both forms pass the server's check against the published
            % schema; a string isn't a number.
            d = prodserver.mcp.internal.mcpDefinition("toySingleHalf", ...
                "toySingleHalf", encoding="Invertible");
            f = @(v) prodserver.mcp.validation.toolArgumentError(d.tools, ...
                struct('x', v), prodserver.mcp.WireEncoding.Invertible);
            test.verifyEqual(f(2), "");
            test.verifyEqual(f("NaN"), "");
            test.verifyEqual(f(struct('type', "single", 'size', [1 1], 'data', 2)), "");
            test.verifyEqual(f("2"), "Argument 'x': expected number, got string.");
        end

        function structsWithDataFieldsUnderJSON(test)
            % Under JSON there is no wrapper, so a struct whose fields are
            % named data, or type and data, is just a struct: published as
            % observed, with no bare forms. The first used to raise
            % "Unrecognized field name "type""; the second was taken for a
            % wrapper and given a number's bare forms.
            d = prodserver.mcp.schema("schemaDataFields", ...
                @() exercise(@schemaDataFields, 2, {3}), encoding="JSON");
            out = d.tools.outputSchema.properties;
            for p = ["r" "t"]
                test.verifyFalse(isfield(out.(p), 'anyOf'), p);
                test.verifyEqual(string(out.(p).type), "object", p);
                test.verifyEqual(string(out.(p).properties.data.type), ...
                    "array", p);
            end
            test.verifyEqual(string(out.t.properties.type.type), "string");
        end

        function structsWithDataFieldsUnderInvertible(test)
            % Wrapped as structs, each with its fields as the data's.
            d = prodserver.mcp.schema("schemaDataFields", ...
                @() exercise(@schemaDataFields, 2, {3}), encoding="Invertible");
            out = d.tools.outputSchema.properties;
            for p = ["r" "t"]
                [w, data] = prodserver.mcp.test.wrapperOf(out.(p));
                test.verifyEqual(string(w.properties.type.enum), "struct", p);
                test.verifyEqual(string(data.type), "object", p);
                test.verifyTrue(isfield(data.properties, 'data'), p);
            end
        end

        function bareStructAcceptsItsOwnEncoding(test)
            % The example describes the fields as plain JSON, but each field
            % of a bare struct is wire-encoded: the bare form must not
            % describe them.
            value = struct('x', [1 2 3], 't', 5, 'n', "hi");
            d = prodserver.mcp.schema("schemaStructInput", ...
                @() schemaStructInput(value), encoding="Invertible");
            tools = jsondecode(jsonencode(d.tools));
            enc = prodserver.mcp.jsonrpc.mcpWireEncodeValue(value);
            args = jsondecode(jsonencode(struct('s', enc)));
            test.verifyEqual(prodserver.mcp.validation.toolArgumentError( ...
                tools, args, prodserver.mcp.WireEncoding.Invertible), "");
            [~, bare] = prodserver.mcp.jsonrpc.bareOrWrapped( ...
                d.tools.inputSchema.properties.s);
            isObject = cellfun(@(b) isfield(b, 'type') && ...
                isequal(string(b.type), "object"), bare);
            test.verifyEqual(nnz(isObject), 1);
            test.verifyFalse(isfield(bare{isObject}, 'properties'));
        end

        function genericWrapperNeedsTypeAndData(test)
            f = @prodserver.mcp.jsonrpc.isGenericWrapper;
            dataOnly = struct('type', "object", 'properties', ...
                struct('data', struct('type', "array")));
            test.verifyFalse(f(dataOnly), "data alone");
            test.verifyFalse(prodserver.mcp.jsonrpc.bareOrWrapped( ...
                struct('anyOf', {{struct('type', "number"), dataOnly}})));
            test.verifyEqual(prodserver.mcp.jsonrpc.allowBareForms(dataOnly), ...
                dataOnly, "Not a wrapper: returned as it is");
            test.verifyTrue(f(prodserver.mcp.jsonrpc.wrapInvertible( ...
                struct('type', "number"))), "A wrapper");
        end

        function countsUnchanged(test)
            % Externalization counts a published schema as its wrapper.
            w = prodserver.mcp.jsonrpc.wrapInvertible(struct('type', "array", ...
                'items', struct('type', "number"), 'maxItems', 100));
            p = prodserver.mcp.jsonrpc.allowBareForms(w);
            [lo1, hi1] = prodserver.mcp.jsonrpc.countSchemaItems(w);
            [lo2, hi2] = prodserver.mcp.jsonrpc.countSchemaItems(p);
            test.verifyEqual([lo2 hi2], [lo1 hi1]);
        end

        % A %#schema's constraints on a scalar

        function bareFormsKeepTheEnum(test)
            % The bare form was the element's type alone, so a bare value
            % escaped the enum the wrapper's data carried.
            p = invertibleInputs("schemaEnums");
            [~, bare] = prodserver.mcp.jsonrpc.bareOrWrapped(p.level);
            test.verifyEqual(bare, {struct('type', "number", 'enum', {{1; 2; 3}})}, ...
                "No NaN, Inf or -Inf: the enum admits none of them");
            [~, bare] = prodserver.mcp.jsonrpc.bareOrWrapped(p.flag);
            test.verifyEqual(bare, {struct('type', "boolean", 'enum', {{true}})});
            [~, bare] = prodserver.mcp.jsonrpc.bareOrWrapped(p.mode);
            test.verifyEqual(string(bare{1}.enum)', ["fast" "slow"]);
            [~, data] = prodserver.mcp.test.wrapperOf(p.level);
            test.verifyFalse(isfield(data, 'anyOf'), ...
                "Nor among the wrapper's data");
        end

        function bareValuesCheckedAgainstTheEnum(test)
            d = prodserver.mcp.internal.mcpDefinition("schemaEnums", ...
                "schemaEnums", encoding="Invertible");
            f = @(n, v) prodserver.mcp.validation.toolArgumentError(d.tools, ...
                struct(n, v), prodserver.mcp.WireEncoding.Invertible);
            w = @(v) struct('type', "double", 'size', [1 1], 'data', v);
            test.verifyEqual(f("level", 2), "");
            test.verifyEqual(f("level", w(2)), "");
            test.verifySubstring(f("level", 4), "is not one of 1, 2, 3");
            test.verifyGreaterThan(strlength(f("level", "NaN")), 0);
            test.verifyGreaterThan(strlength(f("level", w(4))), 0);
            test.verifyGreaterThan(strlength(f("level", w("NaN"))), 0);
            test.verifyEqual(f("mode", "fast"), "");
            test.verifySubstring(f("mode", "medium"), "is not one of");
            test.verifySubstring(f("flag", false), "is not one of true");
        end

        function boundsLimitSpecialFloats(test)
            % "Inf" is at least 0, "-Inf" at most 10; NaN is neither.
            p = invertibleInputs("schemaBounds");
            cases = {"lower", "minimum", "Inf"
                     "upper", "maximum", "-Inf"
                     "both",  "minimum", strings(1, 0)};
            for k = 1:size(cases, 1)
                [~, bare] = prodserver.mcp.jsonrpc.bareOrWrapped(p.(cases{k,1}));
                test.verifyTrue(isfield(bare{1}, cases{k,2}), cases{k,1});
                [~, data] = prodserver.mcp.test.wrapperOf(p.(cases{k,1}));
                [~, wrapped] = prodserver.mcp.jsonrpc.wrapperAlternatives( ...
                    prodserver.mcp.test.wrapperOf(p.(cases{k,1})));
                items = wrapped.properties.data.items;
                if isempty(cases{k,3})
                    test.verifyEqual(numel(bare), 1, cases{k,1});
                    test.verifyFalse(isfield(items, 'anyOf'), cases{k,1});
                else
                    test.verifyEqual(string(bare{2}.enum), cases{k,3}, cases{k,1});
                    test.verifyEqual(string(items.anyOf{2}.enum), cases{k,3}, ...
                        cases{k,1} + " among the data");
                end
                test.verifyTrue(isfield(data, cases{k,2}), cases{k,1});
            end
        end

        function noBareFormsForSeveralElements(test)
            % No bare value has the three elements minItems requires.
            d = prodserver.mcp.internal.mcpDefinition("schemaBounds", ...
                "schemaBounds", encoding="Invertible");
            many = d.tools.inputSchema.properties.many;
            test.verifyFalse(prodserver.mcp.jsonrpc.bareOrWrapped(many));
            test.verifyTrue(prodserver.mcp.jsonrpc.isGenericWrapper(many));
            f = @(v) prodserver.mcp.validation.toolArgumentError(d.tools, ...
                struct('many', v), prodserver.mcp.WireEncoding.Invertible);
            test.verifyGreaterThan(strlength(f(5)), 0);
            test.verifyEqual(f(struct('type', "double", 'size', [1 3], ...
                'data', [1; 2; 3])), "");
        end

    end
end

function p = invertibleInputs(fcn)
% The input schemas of FCN, built under the invertible encoding.
    d = prodserver.mcp.internal.mcpDefinition(fcn, fcn, encoding="Invertible");
    p = d.tools.inputSchema.properties;
end

function exercise(fcn, nout, args)
% Call FCN with ARGS, asking for NOUT outputs, so that every one is observed.
    [varargout{1:nout}] = fcn(args{:}); %#ok<NASGU>
end
