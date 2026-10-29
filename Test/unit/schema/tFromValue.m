classdef tFromValue < matlab.unittest.TestCase
%tFromValue Unit tests for prodserver.mcp.jsonrpc.schemaFromValue.

% Copyright 2026 The MathWorks, Inc.

    methods(TestClassSetup)
        function registerPackage(test)
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            pkgFolder = fullfile(testFolder,"../../..");
            test.applyFixture(PathFixture(pkgFolder));
        end
    end

    methods(Test)

        function scalarDouble(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue(3.14);
            test.verifyEqual(schema.type, "number");
            test.verifyFalse(isfield(schema, 'items'));
        end

        function scalarSingle(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue(single(3.5));
            test.verifyEqual(schema.type, "number");
            schema = prodserver.mcp.jsonrpc.schemaFromValue(single([1 2]));
            test.verifyEqual(schema.items.type, "number");
        end

        function scalarInteger(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue(int32(7));
            test.verifyEqual(schema.type, "integer");
        end

        function scalarString(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue("hello");
            test.verifyEqual(schema.type, "string");
        end

        function scalarChar(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue('hello');
            test.verifyEqual(schema.type, "string");
        end

        function scalarLogical(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue(true);
            test.verifyEqual(schema.type, "boolean");
        end

        function arrayDouble(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue([1 2 3]);
            test.verifyEqual(schema.type, "array");
            test.verifyEqual(schema.items.type, "number");
        end

        function arrayLogical(test)
            % An array of booleans, not one: a boolean schema accepts only
            % a scalar.
            schema = prodserver.mcp.jsonrpc.schemaFromValue([true false true]);
            test.verifyEqual(schema.type, "array");
            test.verifyEqual(schema.items.type, "boolean");
        end

        function typemapForText(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue('abc', ...
                struct('char', "integer"));
            test.verifyEqual(schema.type, "integer");
        end

        function arrayInteger(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue(int16([1 2]));
            test.verifyEqual(schema.type, "array");
            test.verifyEqual(schema.items.type, "integer");
        end

        function matrixDouble(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue([1 2; 3 4]);
            test.verifyEqual(schema.type, "array");
            test.verifyEqual(schema.items.type, "number");
        end

        function flatStruct(test)
            s.x = 1; s.y = 2; s.z = 3;
            schema = prodserver.mcp.jsonrpc.schemaFromValue(s);
            test.verifyEqual(schema.type, "object");
            test.verifyTrue(isfield(schema, 'properties'));
            test.verifyTrue(isfield(schema.properties, 'x'));
            test.verifyTrue(isfield(schema.properties, 'y'));
            test.verifyTrue(isfield(schema.properties, 'z'));
            test.verifyEqual(string(schema.required), ["x","y","z"]);
        end

        function singleFieldRequiredIsArray(test)
            % JSON Schema's required is always an array, even of one name.
            schema = prodserver.mcp.jsonrpc.schemaFromValue(struct('t', 1));
            test.verifyEqual(jsonencode(schema.required), '["t"]');
            test.verifyEqual(jsonencode(schema), ...
                '{"type":"object","required":["t"],"properties":{"t":{"type":"number"}}}');
            % Nested too, and in an array of structs.
            schema = prodserver.mcp.jsonrpc.schemaFromValue( ...
                struct('s', struct('u', 1)));
            test.verifyEqual(jsonencode(schema.properties.s.required), '["u"]');
            schema = prodserver.mcp.jsonrpc.schemaFromValue(struct('t', {1, 2}));
            test.verifyEqual(jsonencode(schema.items.required), '["t"]');
        end

        function toolSchemaRequiredIsArray(test)
            % The repro: a tool whose one parameter is a one-field struct.
            test.applyFixture(prodserver.mcp.test.mixin.RequireSchemaTools());
            d = prodserver.mcp.schema("schemaWireAny", ...
                @() schemaWireAny(struct('t', 1)), encoding="JSON");
            test.verifyTrue(contains(jsonencode(d.tools.inputSchema), ...
                '"required":["t"]'));
            test.verifyTrue(contains(jsonencode(d.tools.inputSchema), ...
                '"required":["x"]'), "The tool's own required list");
        end

        function nestedStruct(test)
            s.material.density = 7800;
            s.material.name = "steel";
            s.length = 3.0;
            schema = prodserver.mcp.jsonrpc.schemaFromValue(s);
            test.verifyEqual(schema.type, "object");
            test.verifyEqual(schema.properties.material.type, "object");
            test.verifyEqual(schema.properties.material.properties.density.type, "number");
            test.verifyEqual(schema.properties.material.properties.name.type, "string");
            test.verifyEqual(schema.properties.length.type, "number");
        end

        function deeplyNestedStruct(test)
            s.a.b.c.d = 42;
            schema = prodserver.mcp.jsonrpc.schemaFromValue(s);
            test.verifyEqual(schema.properties.a.properties.b.properties.c.properties.d.type, "number");
        end

        function stringArrayIsArrayOfStrings(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue(["Alice", "Bob"]);
            test.verifyEqual(schema.type, "array");
            test.verifyEqual(schema.items.type, "string");
            % A string scalar and a char row vector are one string.
            test.verifyEqual(prodserver.mcp.jsonrpc.schemaFromValue("Alice").type, "string");
            test.verifyEqual(prodserver.mcp.jsonrpc.schemaFromValue('Alice').type, "string");
        end

        function structArrayKeepsFields(test)
            s = [struct('name', "a", 'E', 1); struct('name', "b", 'E', 2)];
            schema = prodserver.mcp.jsonrpc.schemaFromValue(s);
            test.verifyEqual(schema.type, "array");
            test.verifyEqual(schema.items.type, "object");
            test.verifyEqual(schema.items.properties.name.type, "string");
            test.verifyEqual(schema.items.properties.E.type, "number");
        end

        function structArrayMixedFieldTypes(test)
            s = [struct('v', 1); struct('v', "one")];
            schema = prodserver.mcp.jsonrpc.schemaFromValue(s);
            test.verifyEqual(schema.type, "array");
            test.verifyNumElements(schema.items.anyOf, 2);
        end

        function emptyStructArray(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue( ...
                struct('a', {}));
            test.verifyEqual(schema.type, "array");
            test.verifyEqual(schema.items.type, "object");
        end

        function emptyStruct(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue(struct());
            test.verifyEqual(schema.type, "object");
            test.verifyFalse(isfield(schema, 'properties'));
        end

        function customTypemap(test)
            tm.double = "custom_number";
            schema = prodserver.mcp.jsonrpc.schemaFromValue(3.14, tm);
            test.verifyEqual(schema.type, "custom_number");
        end

        % A class JSON can't describe gets a tag for the caller to resolve,
        % because whether it can travel depends on the wire encoding.

        function unknownClass(test)
            obj = containers.Map("key", "value");
            schema = prodserver.mcp.jsonrpc.schemaFromValue(obj);
            verifyTag(test, schema, "containers.Map", true);
        end

        function typemapNamesClass(test)
            tm.table = "object";
            schema = prodserver.mcp.jsonrpc.schemaFromValue(table(1), tm);
            test.verifyEqual(schema.type, "object");
            test.verifyFalse(isfield(schema, prodserver.mcp.internal.Constants.ClassTag));
        end

        function cellIsArray(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue({1, 'a'});
            test.verifyEqual(schema.type, "array");
            test.verifyFalse(isfield(schema, prodserver.mcp.internal.Constants.ElementsTag));
        end

        function cellListsTaggedElements(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue({1, @sin});
            test.verifyEqual(schema.type, "array");
            elements = schema.(prodserver.mcp.internal.Constants.ElementsTag);
            test.verifyNumElements(elements, 1);
            verifyTag(test, elements{1}, "function_handle", true);
        end

        function allIntegerTypes(test)
            import prodserver.mcp.jsonrpc.schemaFromValue
            types = {@uint8, @int8, @uint16, @int16, ...
                     @uint32, @int32, @uint64, @int64};
            for i = 1:numel(types)
                schema = schemaFromValue(types{i}(1));
                test.verifyEqual(schema.type, "integer", ...
                    "Failed for " + class(types{i}(1)));
            end
        end

        function singleFloat(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue(single(1.0));
            test.verifyEqual(schema.type, "number");
        end

        function emptyString(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue("");
            test.verifyEqual(schema.type, "string");
        end

        function scalarTable(test)
            T = table(["Alice";"Bob"], [30;25], VariableNames=["Name","Age"]);
            schema = prodserver.mcp.jsonrpc.schemaFromValue(T);
            verifyTag(test, schema, "table", false);
        end

        function scalarDatetime(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue(datetime(2026,1,1));
            verifyTag(test, schema, "datetime", true);
            schema = prodserver.mcp.jsonrpc.schemaFromValue(datetime(2026,1,1:2));
            verifyTag(test, schema, "datetime", false);
        end

        function scalarDuration(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue(hours(1.5));
            verifyTag(test, schema, "duration", true);
        end

        function scalarTimetable(test)
            TT = timetable(hours(1:3)', [10;20;30], VariableNames="Value");
            schema = prodserver.mcp.jsonrpc.schemaFromValue(TT);
            verifyTag(test, schema, "timetable", false);
        end

        function complexArray(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue(complex([1,2],[3,4]));
            test.verifyEqual(schema.type, "array");
            test.verifyEqual(schema.items.type, "number");
        end

    end
end

function verifyTag(test, schema, matlabClass, isScalar)
    test.verifyEqual(schema.(prodserver.mcp.internal.Constants.ClassTag), matlabClass);
    test.verifyEqual(schema.(prodserver.mcp.internal.Constants.ScalarTag), isScalar);
    test.verifyFalse(isfield(schema, 'type'), "A tag is not a schema.");
end
