classdef tObserver < matlab.unittest.TestCase
%tObserver Unit tests for prodserver.mcp.internal.SchemaObserver.

% Copyright 2026 The MathWorks, Inc.

    properties
        toolsFolder
    end

    methods(TestClassSetup)
        function requireToyTools(test)
            rtt = test.applyFixture(...
                prodserver.mcp.test.mixin.RequireToyTools());
            test.toolsFolder = rtt.toolFolder;
        end
    end

    methods(Test)

        function constructsEmpty(test)
            obs = prodserver.mcp.internal.SchemaObserver();
            % Harvest without recording errors — function was never called
            test.verifyError( ...
                @() obs.harvest("toyToolOne", "JSON"), ...
                "prodserver:mcp:SchemaNoObservation");
        end

        function recordPositional(test)
            obs = prodserver.mcp.internal.SchemaObserver();
            obs.record("toyToolOne", "input", ["a","b"], {1.0, uint64(5)}, 2);
            defs = obs.harvest("toyToolOne", "JSON");
            test.verifyEqual(defs.tools.inputSchema.properties.a.type, "number");
            test.verifyEqual(defs.tools.inputSchema.properties.b.type, "integer");
        end

        function recordNVP(test)
            obs = prodserver.mcp.internal.SchemaObserver();
            % toyScalarNVOptions: 1 positional (year), then NVPs
            obs.record("toyScalarNVOptions", "input", "year", ...
                {2024, 'mpg', 3.49, 'range', 4000}, 1);
            defs = obs.harvest("toyScalarNVOptions", "JSON");
            test.verifyEqual(defs.tools.inputSchema.properties.year.type, "number");
            test.verifyEqual(defs.tools.inputSchema.properties.mpg.type, "number");
            test.verifyEqual(defs.tools.inputSchema.properties.range.type, "number");
        end

        function recordMultipleCalls(test)
            obs = prodserver.mcp.internal.SchemaObserver();
            obs.record("toyToolOne", "input", ["a","b"], {1.0, uint64(5)}, 2);
            obs.record("toyToolOne", "input", ["a","b"], {2.0, uint64(10)}, 2);
            defs = obs.harvest("toyToolOne", "JSON");
            % Same types → deduplicated to single schema
            test.verifyEqual(defs.tools.inputSchema.properties.a.type, "number");
            test.verifyFalse(isfield(defs.tools.inputSchema.properties.a, 'anyOf'));
        end

        function harvestDeduplicates(test)
            obs = prodserver.mcp.internal.SchemaObserver();
            % Record same type 3 times
            obs.record("toyToolOne", "input", ["a","b"], {1.0, uint64(1)}, 2);
            obs.record("toyToolOne", "input", ["a","b"], {2.0, uint64(2)}, 2);
            obs.record("toyToolOne", "input", ["a","b"], {3.0, uint64(3)}, 2);
            defs = obs.harvest("toyToolOne", "JSON");
            % All identical → single schema, no anyOf
            test.verifyEqual(defs.tools.inputSchema.properties.a.type, "number");
            test.verifyFalse(isfield(defs.tools.inputSchema.properties.a, 'anyOf'));
        end

        function harvestAnyOf(test)
            obs = prodserver.mcp.internal.SchemaObserver();
            % Record different types for same argument
            obs.record("toyToolOne", "input", ["a","b"], {1.0, uint64(5)}, 2);
            obs.record("toyToolOne", "input", ["a","b"], {"text", uint64(5)}, 2);
            defs = obs.harvest("toyToolOne", "JSON");
            % 'a' received number and string → anyOf
            test.verifyTrue(isfield(defs.tools.inputSchema.properties.a, 'anyOf'));
            test.verifyEqual(numel(defs.tools.inputSchema.properties.a.anyOf), 2);
        end

        function harvestRequiredFields(test)
            obs = prodserver.mcp.internal.SchemaObserver();
            obs.record("toyToolOne", "input", ["a","b"], {1.0, uint64(5)}, 2);
            defs = obs.harvest("toyToolOne", "JSON");
            % toyToolOne has both a and b required
            test.verifyTrue(ismember("a", defs.tools.inputSchema.required));
            test.verifyTrue(ismember("b", defs.tools.inputSchema.required));
        end

        function harvestOptionalFields(test)
            obs = prodserver.mcp.internal.SchemaObserver();
            obs.record("toyScalarNVOptions", "input", "year", ...
                {2024, 'mpg', 3.49}, 1);
            defs = obs.harvest("toyScalarNVOptions", "JSON");
            % 'year' is required; NVPs are optional
            test.verifyTrue(ismember("year", defs.tools.inputSchema.required));
            test.verifyFalse(ismember("mpg", defs.tools.inputSchema.required));
        end

        function harvestMultipleTools(test)
            obs = prodserver.mcp.internal.SchemaObserver();
            obs.record("toyToolOne", "input", ["a","b"], {1.0, uint64(5)}, 2);
            obs.record("toyScalarTwo", "input", ["p","q"], {1.0, 2.0}, 2);
            defs = obs.harvest(["toyToolOne", "toyScalarTwo"], "JSON");
            test.verifyEqual(numel(defs), 2);
            test.verifyEqual(defs(1).tools.name, "toyToolOne");
            test.verifyEqual(defs(2).tools.name, "toyScalarTwo");
        end

        function harvestProducesDefinition(test)
            obs = prodserver.mcp.internal.SchemaObserver();
            obs.record("toyToolOne", "input", ["a","b"], {1.0, uint64(5)}, 2);
            obs.record("toyToolOne", "output", ["x","y","z"], {5.0, 69.0, 4.0}, 3);
            defs = obs.harvest("toyToolOne", "JSON");
            % Verify definition structure fields
            test.verifyTrue(isfield(defs, 'tools'));
            test.verifyTrue(isfield(defs.tools, 'name'));
            test.verifyTrue(isfield(defs.tools, 'description'));
            test.verifyTrue(isfield(defs.tools, 'inputSchema'));
            test.verifyTrue(isfield(defs.tools, 'outputSchema'));
            test.verifyTrue(isfield(defs, 'signatures'));
        end

        function customTypemap(test)
            tm.double = "custom_float";
            obs = prodserver.mcp.internal.SchemaObserver(tm);
            obs.record("toyToolOne", "input", ["a","b"], {1.0, uint64(5)}, 2);
            defs = obs.harvest("toyToolOne", "JSON");
            test.verifyEqual(defs.tools.inputSchema.properties.a.type, "custom_float");
        end

        function emptyHarvest(test)
            obs = prodserver.mcp.internal.SchemaObserver();
            % No records — harvest errors for unexercised functions
            test.verifyError( ...
                @() obs.harvest("toyToolOne", "JSON"), ...
                "prodserver:mcp:SchemaNoObservation");
        end

    end
end
