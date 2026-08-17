classdef tSchemaEquivalence < matlab.unittest.TestCase
%tSchemaEquivalence Verify prodserver.mcp.schema produces schemas equivalent
%   to prodserver.mcp.internal.mcpDefinition for functions with argument blocks.
%
%   "Equivalent" means: the JSON Schema type information for each parameter
%   matches. Known differences are accounted for:
%   - mcpDefinition adds parameter descriptions from comments
%   - mcpDefinition applies wire-encoding wrappers (Invertible)
%   - mcpDefinition adds minProperties/maxProperties
%   - mcpDefinition populates richer signatures metadata
%
%   This test compares the structural type information: for each parameter,
%   the JSON Schema type (number, integer, string, array, object) and
%   required/optional classification must match.

% Copyright 2026 The MathWorks, Inc.

    properties
        toyToolsFolder
        paramToolsFolder
    end

    methods(TestClassSetup)
        function requireToyTools(test)
            rtt = test.applyFixture(...
                prodserver.mcp.test.mixin.RequireToyTools());
            test.toyToolsFolder = rtt.toolFolder;
        end

        function requireParamTools(test)
            rpt = test.applyFixture(...
                prodserver.mcp.test.mixin.RequireParamTools());
            test.paramToolsFolder = rpt.toolFolder;
        end
    end

    methods(Test)

        % --- Toy Tools ---

        function toyToolOne(test)
            % toyToolOne(a double, b uint64) -> [x, y, z]
            % Outputs are untyped in the argument block, so only compare inputs.
            verifyEquivalence(test, "toyToolOne", ...
                @() callWithOutputs(@toyToolOne, 3, {1.0, uint64(5)}), ...
                CompareOutputs=false);
        end

        function toyScalarOne(test)
            % toyScalarOne(x double) -> [y]
            verifyEquivalence(test, "toyScalarOne", ...
                @() callWithOutputs(@toyScalarOne, 1, {42.0}));
        end

        function toyScalarTwo(test)
            % toyScalarTwo(s string, n double) -> [cs, d]
            verifyEquivalence(test, "toyScalarTwo", ...
                @() callWithOutputs(@toyScalarTwo, 2, {"hello world", 3.0}));
        end

        function toyScalarFour(test)
            % toyScalarFour(a,c,m,x0 all double) -> [x]
            verifyEquivalence(test, "toyScalarFour", ...
                @() callWithOutputs(@toyScalarFour, 1, {7.0, 3.0, 10.0, 1.0}));
        end

        function toyScalarNVOptions(test)
            % toyScalarNVOptions(year double, opts.mpg double, opts.range double,
            %   opts.make string, opts.model string) -> [report]
            verifyEquivalence(test, "toyScalarNVOptions", ...
                @() callWithOutputs(@toyScalarNVOptions, 1, ...
                    {2024.0, 'mpg', 3.49, 'range', 4000.0, ...
                     'make', "Lockheed", 'model', "Electra"}));
        end

        function toyScalarOptions(test)
            % toyScalarOptions(year double, mpg double, range double,
            %   make string, model string) -> [report]
            verifyEquivalence(test, "toyScalarOptions", ...
                @() callWithOutputs(@toyScalarOptions, 1, ...
                    {2024.0, 3.49, 4000.0, "Lockheed", "Electra"}));
        end

        % --- Parameter Tools ---

        function threeFour(test)
            verifyEquivalence(test, "threeFour", ...
                @() callWithOutputs(@threeFour, 3, {1.0, 2.0, 3.0, 4.0}));
        end

        function allInOptional(test)
            verifyEquivalence(test, "allInOptional", ...
                @() callWithOutputs(@allInOptional, 3, {1.0, 2.0, 3.0, 4.0}));
        end

        function someInNVP(test)
            verifyEquivalence(test, "someInNVP", ...
                @() callWithOutputs(@someInNVP, 3, ...
                    {1.0, 2.0, 'c', 3.0, 'd', 4.0}));
        end

        function orderMatters(test)
            verifyEquivalence(test, "orderMatters", ...
                @() callWithOutputs(@orderMatters, 3, {1.0, 2.0, 3.0, 4.0}));
        end

    end

    methods(Access = private)

        function verifyEquivalence(test, toolName, exercise, opts)
        %verifyEquivalence Compare schema() output against mcpDefinition().
            arguments
                test
                toolName
                exercise
                opts.CompareOutputs (1,1) logical = true
            end

            % Get the reference definition from mcpDefinition
            expected = prodserver.mcp.internal.mcpDefinition(toolName, toolName, ...
                encoding="JSON");

            % Get the observed definition from schema()
            observed = prodserver.mcp.schema(toolName, exercise, ...
                encoding="JSON");

            % Compare tool name
            test.verifyEqual(observed.tools.name, expected.tools.name, ...
                "Tool name mismatch");

            % Compare input schema types and required
            verifySchemaEquivalent(test, ...
                observed.tools.inputSchema, ...
                expected.tools.inputSchema, ...
                "inputSchema");

            % Compare output schema types and required
            if opts.CompareOutputs
                verifySchemaEquivalent(test, ...
                    observed.tools.outputSchema, ...
                    expected.tools.outputSchema, ...
                    "outputSchema");
            end
        end

        function verifySchemaEquivalent(test, observed, expected, label)
        %verifySchemaEquivalent Compare two schema structs for type equivalence.

            % Both should be objects
            test.verifyEqual(observed.type, expected.type, ...
                label + ": top-level type mismatch");

            % Compare properties
            if isfield(expected, 'properties')
                test.verifyTrue(isfield(observed, 'properties'), ...
                    label + ": missing properties field");

                expectedNames = sort(string(fieldnames(expected.properties)));
                observedNames = sort(string(fieldnames(observed.properties)));
                test.verifyEqual(observedNames, expectedNames, ...
                    label + ": parameter names mismatch");

                % Compare each parameter's type
                for i = 1:numel(expectedNames)
                    name = expectedNames(i);
                    expParam = expected.properties.(name);
                    obsParam = observed.properties.(name);
                    verifyParameterType(test, obsParam, expParam, ...
                        label + "." + name);
                end
            end

            % Compare required arrays
            if isfield(expected, 'required') && ~isempty(expected.required)
                test.verifyTrue(isfield(observed, 'required'), ...
                    label + ": missing required field");
                test.verifyEqual(sort(string(observed.required)), ...
                    sort(string(expected.required)), ...
                    label + ": required mismatch");
            else
                if isfield(observed, 'required')
                    test.verifyTrue(isempty(observed.required), ...
                        label + ": unexpected required field");
                end
            end
        end

        function verifyParameterType(test, observed, expected, label)
        %verifyParameterType Compare the JSON Schema type of a single parameter.
        %   Accounts for the structural difference: mcpDefinition may use
        %   "array" with "items" for non-scalar parameters.

            obsType = getEffectiveType(observed);
            expType = getEffectiveType(expected);

            test.verifyEqual(obsType, expType, ...
                label + ": type mismatch");

            % For array types, compare items type
            if obsType == "array" && isfield(observed, 'items') && isfield(expected, 'items')
                test.verifyEqual(observed.items.type, expected.items.type, ...
                    label + ".items: type mismatch");
            end
        end

    end
end

function t = getEffectiveType(param)
%getEffectiveType Extract the effective JSON Schema type from a parameter.
%   Handles both direct types and array-wrapped types.
    if isfield(param, 'type')
        t = string(param.type);
    else
        t = "object";
    end
end

function callWithOutputs(fcn, nout, args)
    [varargout{1:nout}] = fcn(args{:}); %#ok<VARARG>
end
