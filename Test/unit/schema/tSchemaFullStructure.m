classdef tSchemaFullStructure < matlab.unittest.TestCase
%tSchemaFullStructure Full structural validation of schema() output.
%   Compares the complete definition struct (tools + signatures) produced
%   by schema() against mcpDefinition() for functions with argument blocks.
%   Tests both JSON and Invertible encodings via parametrization.
%
%   Overlaps with tSchemaRoundTrip and tSchemaEquivalence, which perform
%   partial comparisons. This test asserts full structural equality.

% Copyright 2026 The MathWorks, Inc.

    properties(TestParameter)
        encoding = {"JSON", "Invertible"}
    end

    methods(TestClassSetup)
        function requireToyTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireToyTools());
        end

        function requireSchemaTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end

        function requireParamTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireParamTools());
        end
    end

    methods(Test)

        function fullToyScalarOne(test, encoding)
            verifyFull(test, "toyScalarOne", ...
                @() callWithOutputs(@toyScalarOne, 1, {42.0}), encoding);
        end

        function fullToyScalarTwo(test, encoding)
            verifyFull(test, "toyScalarTwo", ...
                @() callWithOutputs(@toyScalarTwo, 2, {"hello world", 3.0}), ...
                encoding);
        end

        function fullToyScalarNVOptions(test, encoding)
            verifyFull(test, "toyScalarNVOptions", ...
                @() callWithOutputs(@toyScalarNVOptions, 1, ...
                    {2024.0, 'mpg', 3.49, 'range', 4000.0, ...
                     'make', "Lockheed", 'model', "Electra"}), encoding);
        end

        function fullSchemaCompute(test, encoding)
            verifyFull(test, "schemaCompute", ...
                @() callWithOutputs(@schemaCompute, 3, ...
                    {1.0, 2.0, 3.0, 'scale', 2.0, 'label', "test"}), ...
                encoding);
        end

        function fullThreeFour(test, encoding)
            verifyFull(test, "threeFour", ...
                @() callWithOutputs(@threeFour, 3, {1.0, 2.0, 3.0, 4.0}), ...
                encoding);
        end

        function fullAllInOptional(test, encoding)
            verifyFull(test, "allInOptional", ...
                @() callWithOutputs(@allInOptional, 3, {1.0, 2.0, 3.0, 4.0}), ...
                encoding);
        end

        function fullSomeInNVP(test, encoding)
            verifyFull(test, "someInNVP", ...
                @() callWithOutputs(@someInNVP, 3, ...
                    {1.0, 2.0, 'c', 3.0, 'd', 4.0}), encoding);
        end

    end

    methods(Access = private)

        function verifyFull(test, name, exercise, encoding)
            enc = prodserver.mcp.WireEncoding(encoding);
            observed = prodserver.mcp.schema(name, exercise, encoding=enc);
            expected = prodserver.mcp.internal.mcpDefinition(name, name, ...
                encoding=enc);

            test.verifyEqual(observed.tools.name, expected.tools.name, ...
                name + ": tool name");
            test.verifyEqual(observed.tools.description, ...
                expected.tools.description, name + ": tool description");
            test.verifyEqual(observed.tools.inputSchema, ...
                expected.tools.inputSchema, name + ": inputSchema");
            test.verifyEqual(observed.tools.outputSchema, ...
                expected.tools.outputSchema, name + ": outputSchema");
            verifySigEqual(test, observed.signatures, ...
                expected.signatures, name);
        end

        function verifySigEqual(test, observed, expected, name)
        %verifySigEqual Compare signatures excluding validation/default.
        %   validation and default require parsing argument block text which
        %   SchemaObserver does not do. Compare all other sig fields.
            obsSig = observed.(name);
            expSig = expected.(name);

            test.verifyEqual(obsSig.function, expSig.function, ...
                name + ": signatures.function");

            ios = ["input", "output"];
            for k = 1:numel(ios)
                io = ios(k);
                if ~isfield(expSig, io), continue; end
                test.verifyTrue(isfield(obsSig, io), ...
                    name + ": signatures." + io + " missing");
                obs = obsSig.(io);
                exp = expSig.(io);
                test.verifyEqual(obs.name, exp.name, ...
                    name + ": sig." + io + ".name");
                test.verifyEqual(obs.type, exp.type, ...
                    name + ": sig." + io + ".type");
                test.verifyEqual(obs.kind, exp.kind, ...
                    name + ": sig." + io + ".kind");
                test.verifyEqual(obs.order, exp.order, ...
                    name + ": sig." + io + ".order");
                test.verifyEqual(obs.group, exp.group, ...
                    name + ": sig." + io + ".group");
            end
        end

    end
end

function callWithOutputs(fcn, nout, args)
    [varargout{1:nout}] = fcn(args{:}); %#ok<VARARG>
end
