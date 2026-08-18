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
            test.verifyEqual(schema.required, ["x","y","z"]);
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

        function unknownClass(test)
            obj = containers.Map("key", "value");
            schema = prodserver.mcp.jsonrpc.schemaFromValue(obj);
            test.verifyEqual(schema.type, "object");
            test.verifyTrue(contains(schema.description, "containers.Map"));
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
            test.verifyEqual(schema.type, "object");
            test.verifyTrue(contains(schema.description, "table"));
        end

        function scalarDatetime(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue(datetime(2026,1,1));
            test.verifyEqual(schema.type, "object");
            test.verifyTrue(contains(schema.description, "datetime"));
        end

        function scalarDuration(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue(hours(1.5));
            test.verifyEqual(schema.type, "object");
            test.verifyTrue(contains(schema.description, "duration"));
        end

        function scalarTimetable(test)
            TT = timetable(hours(1:3)', [10;20;30], VariableNames="Value");
            schema = prodserver.mcp.jsonrpc.schemaFromValue(TT);
            test.verifyEqual(schema.type, "object");
            test.verifyTrue(contains(schema.description, "timetable"));
        end

        function complexArray(test)
            schema = prodserver.mcp.jsonrpc.schemaFromValue(complex([1,2],[3,4]));
            test.verifyEqual(schema.type, "array");
            test.verifyEqual(schema.items.type, "number");
        end

    end
end
