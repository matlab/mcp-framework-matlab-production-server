classdef tSchema < matlab.unittest.TestCase
%tSchema Integration tests for prodserver.mcp.schema using toy tools.

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

        function requireSchemaTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods(Test)

        function singleToolScalarInputs(test)
            defs = prodserver.mcp.schema("toyToolOne", ...
                @() callWithOutputs(@toyToolOne, 3, {1.0, uint64(5)}), ...
                encoding="JSON");
            test.verifyEqual(defs.tools.inputSchema.properties.a.type, "number");
            test.verifyEqual(defs.tools.inputSchema.properties.b.type, "integer");
        end

        function singleToolMultipleOutputs(test)
            defs = prodserver.mcp.schema("toyToolOne", ...
                @() callWithOutputs(@toyToolOne, 3, {1.0, uint64(5)}), ...
                encoding="JSON");
            test.verifyTrue(isfield(defs.tools.outputSchema.properties, 'x'));
            test.verifyTrue(isfield(defs.tools.outputSchema.properties, 'y'));
            test.verifyTrue(isfield(defs.tools.outputSchema.properties, 'z'));
        end

        function functionHandleTest(test)
            defs = prodserver.mcp.schema("toyScalarOne", ...
                @() callWithOutputs(@toyScalarOne, 1, {42.0}), ...
                encoding="JSON");
            test.verifyEqual(defs.tools.inputSchema.properties.x.type, "number");
        end

        function multipleToolsSingleTest(test)
            defs = prodserver.mcp.schema(...
                ["toyToolOne","toyScalarTwo"], ...
                @() callBothTools(), encoding="JSON");
            test.verifyEqual(numel(defs), 2);
            test.verifyEqual(defs(1).tools.name, "toyToolOne");
            test.verifyEqual(defs(2).tools.name, "toyScalarTwo");
        end

        function multipleTests(test)
            defs = prodserver.mcp.schema("toyToolOne", ...
                {@() callWithOutputs(@toyToolOne, 3, {1.0, uint64(5)}), ...
                 @() callWithOutputs(@toyToolOne, 3, {2.0, uint64(10)})}, ...
                encoding="JSON");
            % Both calls contribute — should still deduplicate
            test.verifyEqual(defs.tools.inputSchema.properties.a.type, "number");
            test.verifyFalse(isfield(defs.tools.inputSchema.properties.a, 'anyOf'));
        end

        function optionalNVPInputs(test)
            defs = prodserver.mcp.schema("toyScalarNVOptions", ...
                @() callWithOutputs(@toyScalarNVOptions, 1, ...
                    {2024, 'mpg', 3.49, 'range', 4000}), ...
                encoding="JSON");
            test.verifyTrue(isfield(defs.tools.inputSchema.properties, 'year'));
            test.verifyTrue(isfield(defs.tools.inputSchema.properties, 'mpg'));
            test.verifyTrue(isfield(defs.tools.inputSchema.properties, 'range'));
            test.verifyEqual(defs.tools.inputSchema.properties.mpg.type, "number");
        end

        function returnedDefinitionValid(test)
            defs = prodserver.mcp.schema("toyToolOne", ...
                @() callWithOutputs(@toyToolOne, 3, {1.0, uint64(5)}), ...
                encoding="JSON");
            test.verifyTrue(isfield(defs, 'tools'));
            test.verifyTrue(isfield(defs, 'signatures'));
            test.verifyTrue(isfield(defs.tools, 'name'));
            test.verifyTrue(isfield(defs.tools, 'description'));
            test.verifyTrue(isfield(defs.tools, 'inputSchema'));
            test.verifyTrue(isfield(defs.tools, 'outputSchema'));
        end

        function pathRestoredOnSuccess(test)
            pathBefore = path();
            prodserver.mcp.schema("toyToolOne", ...
                @() callWithOutputs(@toyToolOne, 3, {1.0, uint64(5)}), ...
                encoding="JSON");
            test.verifyEqual(path(), pathBefore);
        end

        function pathRestoredOnError(test)
            pathBefore = path();
            try
                prodserver.mcp.schema("toyToolOne", ...
                    @() error("test:deliberate", "Deliberate error"), ...
                    encoding="JSON");
            catch
                % Expected
            end
            test.verifyEqual(path(), pathBefore);
        end

        function testErrorMsgPropagates(test)
            msg = "Deliberate error";
            badFcn = @() prodserver.mcp.schema("toyToolOne", ...
                @() error("test:deliberate", "Deliberate error"), ...
                encoding="JSON");
            test.verifyError(badFcn, ...
                "prodserver:mcp:ExampleFcnFailed");
            try
                badFcn();
                test.verifyTrue(false,"Expected exception did not occur.");
            catch me
                test.verifyTrue(contains(me.message,msg), ...
                    "Error message did not propagate");
            end
        end

        function appdataCleanedUp(test)
            prodserver.mcp.schema("toyToolOne", ...
                @() callWithOutputs(@toyToolOne, 3, {1.0, uint64(5)}), ...
                encoding="JSON");
            test.verifyFalse(isappdata(0, 'MCPSchemaObserver'));
        end

        function functionNotOnPathErrors(test)
            test.verifyError(...
                @() prodserver.mcp.schema("nonExistentFunction_xyz123", ...
                    @() disp("nope"), encoding="JSON"), ...
                "prodserver:mcp:SchemaFcnNotFound");
        end

        function emptyFcnsErrors(test)
            test.verifyError(...
                @() prodserver.mcp.schema(string.empty, @() 1), ...
                "MATLAB:validators:mustBeNonempty");
        end

        function invalidExampleTypeErrors(test)
            test.verifyError(...
                @() prodserver.mcp.schema("schemaComputeNoBlock", 42), ...
                "prodserver:mcp:InvalidExampleType");
        end

        function emptyExampleErrors(test)
            test.verifyError(...
                @() prodserver.mcp.schema("schemaComputeNoBlock", []), ...
                "MATLAB:validators:mustBeNonempty");
        end

        function nonScalarTypemapErrors(test)
            test.verifyError(...
                @() prodserver.mcp.schema("schemaComputeNoBlock", ...
                    @() schemaComputeNoBlock(1,2,3), ...
                    typemap=struct('a',{1,2})), ...
                "MATLAB:validators:mustBeScalarOrEmpty");
        end

        function unexercisedFunctionErrors(test)
            % Test exercises toyScalarOne but not schemaComputeNoBlock
            test.verifyError(...
                @() prodserver.mcp.schema( ...
                    ["toyScalarOne", "schemaComputeNoBlock"], ...
                    @() toyScalarOne(1.0), encoding="JSON"), ...
                "prodserver:mcp:SchemaNoObservation");
        end

        function structuredTypeInputs(test)
            defs = prodserver.mcp.schema("schemaComplexNoBlock", ...
                @() callWithOutputs(@schemaComplexNoBlock, 3, ...
                    {[3,0], [4,1]}), encoding="JSON");
            test.verifyEqual(defs.tools.inputSchema.properties.realPart.type, "array");
            test.verifyEqual(defs.tools.inputSchema.properties.imagPart.type, "array");
        end

        function structuredTypeOutputs(test)
            defs = prodserver.mcp.schema("schemaDatetimeNoBlock", ...
                @() callWithOutputs(@schemaDatetimeNoBlock, 3, ...
                    {2026, 3, 15}), encoding="JSON");
            test.verifyTrue(isfield(defs.tools.outputSchema.properties, 'dt'));
            test.verifyTrue(isfield(defs.tools.outputSchema.properties, 'dow'));
            test.verifyTrue(isfield(defs.tools.outputSchema.properties, 'serial'));
            test.verifyEqual(defs.tools.outputSchema.properties.dt.type, "object");
            test.verifyEqual(defs.tools.outputSchema.properties.serial.type, "number");
        end

    end
end

function callBothTools()
    [~,~,~] = toyToolOne(1.0, uint64(5));
    [~,~] = toyScalarTwo(3.0, 4.0);
end

function callWithOutputs(fcn, nout, args)
    [varargout{1:nout}] = fcn(args{:}); 
end
