classdef tSchemaInvertible < matlab.unittest.TestCase
%tSchemaInvertible Verify observation behavior under Invertible wire encoding.
%   Mirrors key tests from tSchema and tSchemaParams but navigates through
%   the wire encoding wrapper to verify correct observed types inside data.

% Copyright 2026 The MathWorks, Inc.

    methods(TestClassSetup)
        function requireToyTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireToyTools());
        end

        function requireParamTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireParamTools());
        end

        function requireSchemaTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods(Test)

        function singleToolScalarInputs(test)
            defs = prodserver.mcp.schema("toyToolOne", ...
                @() callWithOutputs(@toyToolOne, 3, {1.0, uint64(5)}));
            test.verifyEqual(unwrapType(defs.tools.inputSchema.properties.a), "number");
            test.verifyEqual(unwrapType(defs.tools.inputSchema.properties.b), "integer");
        end

        function nvpInputsWrapped(test)
            defs = prodserver.mcp.schema("toyScalarNVOptions", ...
                @() callWithOutputs(@toyScalarNVOptions, 1, ...
                    {2024, 'mpg', 3.49, 'range', 4000}));
            test.verifyEqual(unwrapType(defs.tools.inputSchema.properties.year), "number");
            test.verifyEqual(unwrapType(defs.tools.inputSchema.properties.mpg), "number");
            test.verifyEqual(unwrapType(defs.tools.inputSchema.properties.range), "number");
        end

        function multipleToolsWrapped(test)
            defs = prodserver.mcp.schema( ...
                ["toyToolOne","toyScalarTwo"], ...
                @() callBothTools());
            test.verifyEqual(numel(defs), 2);
            test.verifyEqual(unwrapType(defs(1).tools.inputSchema.properties.a), "number");
            test.verifyEqual(unwrapType(defs(2).tools.inputSchema.properties.s), "string");
        end

        function multipleExercisesDeduplicates(test)
            defs = prodserver.mcp.schema("toyToolOne", ...
                {@() callWithOutputs(@toyToolOne, 3, {1.0, uint64(5)}), ...
                 @() callWithOutputs(@toyToolOne, 3, {2.0, uint64(10)})});
            data = unwrapData(defs.tools.inputSchema.properties.a);
            test.verifyEqual(string(data.type), "number");
            test.verifyFalse(isfield(data, 'anyOf'));
        end

        function anyOfInsideWrapper(test)
            obs = prodserver.mcp.internal.SchemaObserver();
            obs.record("toyToolOne", "input", ["a","b"], {1.0, uint64(5)}, 2);
            obs.record("toyToolOne", "input", ["a","b"], {"text", uint64(5)}, 2);
            defs = obs.harvest("toyToolOne", "Invertible");
            data = unwrapData(defs.tools.inputSchema.properties.a);
            test.verifyTrue(isfield(data, 'anyOf'));
            test.verifyEqual(numel(data.anyOf), 2);
        end

        function correctTypes(test)
            defs = prodserver.mcp.schema("threeFour", ...
                @() callWithOutputs(@threeFour, 3, {1.0, 2.0, 3.0, 4.0}));
            test.verifyEqual(unwrapType(defs.tools.inputSchema.properties.a), "number");
            test.verifyEqual(unwrapType(defs.tools.inputSchema.properties.b), "number");
            test.verifyEqual(unwrapType(defs.tools.inputSchema.properties.c), "number");
            test.verifyEqual(unwrapType(defs.tools.inputSchema.properties.d), "number");
        end

        function allRequiredWrapped(test)
            defs = prodserver.mcp.schema("threeFour", ...
                @() callWithOutputs(@threeFour, 3, {1, 2, 3, 4}));
            test.verifyEqual(numel(defs.tools.inputSchema.required), 4);
            test.verifyTrue(all(ismember(["a","b","c","d"], ...
                defs.tools.inputSchema.required)));
        end

        function allOptionalWrapped(test)
            defs = prodserver.mcp.schema("allInOptional", ...
                @() callWithOutputs(@allInOptional, 3, {1, 2, 3, 4}));
            test.verifyTrue(isempty(defs.tools.inputSchema.required));
            % All params present and wire-encoded
            test.verifyEqual(string(defs.tools.inputSchema.properties.a.type), "object");
            test.verifyEqual(string(defs.tools.inputSchema.properties.d.type), "object");
        end

        function mixedNVPWrapped(test)
            defs = prodserver.mcp.schema("someInNVP", ...
                @() callWithOutputs(@someInNVP, 3, {1, 2, 'c', 3, 'd', 4}));
            test.verifyTrue(ismember("a", defs.tools.inputSchema.required));
            test.verifyTrue(ismember("b", defs.tools.inputSchema.required));
            test.verifyFalse(ismember("c", defs.tools.inputSchema.required));
            test.verifyFalse(ismember("d", defs.tools.inputSchema.required));
            test.verifyEqual(unwrapType(defs.tools.inputSchema.properties.c), "number");
            test.verifyEqual(unwrapType(defs.tools.inputSchema.properties.d), "number");
        end

        function unobservedParameterWrapped(test)
            % Only provide some NVPs — unobserved params get fallback type
            defs = prodserver.mcp.schema("someInNVP", ...
                @() callWithOutputs(@someInNVP, 3, {1, 2, 'c', 3}));
            % 'd' not exercised — should still be wrapped with fallback type
            test.verifyEqual(string(defs.tools.inputSchema.properties.d.type), "object");
            test.verifyTrue(isfield(defs.tools.inputSchema.properties.d, 'properties'));
            test.verifyTrue(isfield(defs.tools.inputSchema.properties.d.properties, 'data'));
        end

        function structuredTypeWrapped(test)
            defs = prodserver.mcp.schema("schemaComplexNoBlock", ...
                @() callWithOutputs(@schemaComplexNoBlock, 3, ...
                    {[3,0], [4,1]}));
            param = defs.tools.inputSchema.properties.realPart;
            test.verifyEqual(string(param.type), "object");
            test.verifyTrue(isfield(param, 'properties'));
            test.verifyTrue(isfield(param.properties, 'data'));
            data = param.properties.data;
            test.verifyEqual(string(data.type), "array");
        end

        function structuredOutputWrapped(test)
            defs = prodserver.mcp.schema("schemaDatetimeNoBlock", ...
                @() callWithOutputs(@schemaDatetimeNoBlock, 3, ...
                    {2026, 3, 15}));
            outSchema = defs.tools.outputSchema;
            test.verifyTrue(isfield(outSchema.properties, 'dt'));
            test.verifyTrue(isfield(outSchema.properties, 'serial'));
            dtParam = outSchema.properties.dt;
            test.verifyEqual(string(dtParam.type), "object");
            test.verifyTrue(isfield(dtParam, 'properties'));
            test.verifyTrue(isfield(dtParam.properties, 'data'));
        end

    end
end

function data = unwrapData(param)
%unwrapData Extract the data field from a wire-encoded parameter.
    data = param.properties.data;
end

function t = unwrapType(param)
%unwrapType Extract the inner type from a wire-encoded parameter.
    data = param.properties.data;
    t = string(data.type);
end

function callBothTools()
    [~,~,~] = toyToolOne(1.0, uint64(5));
    [~,~] = toyScalarTwo("hello world", 3.0);
end

function callWithOutputs(fcn, nout, args)
    [varargout{1:nout}] = fcn(args{:}); %#ok<VARARG>
end
