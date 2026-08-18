classdef tCountSchemaItems < matlab.unittest.TestCase
% Test prodserver.mcp.jsonrpc.countSchemaItems (recursively count the min/max
% number of scalar items a JSON-Schema parameter definition can hold).

% Copyright 2026 The MathWorks, Inc.

    methods

        function verifyCount(test, schema, expMin, expMax)
            [minItems, maxItems] = ...
                prodserver.mcp.jsonrpc.countSchemaItems(schema);
            test.verifyEqual(minItems, expMin);
            test.verifyEqual(maxItems, expMax);
        end

    end

    methods (Test)

        function tEmptyAndNoArg(test)
            % No schema / empty schema is unbounded.
            [minItems, maxItems] = prodserver.mcp.jsonrpc.countSchemaItems();
            test.verifyEqual(minItems, 0);
            test.verifyEqual(maxItems, Inf);
            test.verifyCount([], 0, Inf);
        end

        function tNonStructIsUnbounded(test)
            % e.g. additionalProperties given as literal true.
            test.verifyCount(true, 0, Inf);
        end

        function tScalarTypes(test)
            test.verifyCount(struct("type", "string"), 1, 1);
            test.verifyCount(struct("type", "integer"), 1, 1);
            test.verifyCount(struct("type", "boolean"), 1, 1);
        end

        function tTypeAsCellUsesFirst(test)
            % type given as ["string","null"] uses the first entry.
            s.type = {'string', 'null'};
            test.verifyCount(s, 1, 1);
        end

        function tObjectSumsFields(test)
            % Required field contributes to min; all fields contribute to max.
            obj = struct("type", "object", ...
                "properties", struct("name", struct("type", "string"), ...
                                      "age", struct("type", "integer")), ...
                "required", {{'name'}});
            test.verifyCount(obj, 1, 2);
        end

        function tRequiredAsStringScalar(test)
            % 'required' given as a scalar string rather than a cell array.
            rs = struct("type", "object", ...
                "properties", struct("a", struct("type", "string")));
            rs.required = "a";
            test.verifyCount(rs, 1, 1);
        end

        function tUnboundedAdditionalProperties(test)
            obj = struct("type", "object", ...
                "properties", struct("name", struct("type", "string")), ...
                "required", {{'name'}});
            objTrue = obj; objTrue.additionalProperties = true;
            test.verifyCount(objTrue, 1, Inf);
            objSchema = obj; objSchema.additionalProperties = struct("type", "string");
            test.verifyCount(objSchema, 1, Inf);
        end

        function tArrayOfPrimitives(test)
            arr = struct("type", "array", "items", struct("type", "number"), ...
                "minItems", 2, "maxItems", 5);
            test.verifyCount(arr, 2, 5);
        end

        function tArrayNoItemsNoBounds(test)
            % No item schema and no bounds: 0 .. Inf.
            test.verifyCount(struct("type", "array"), 0, Inf);
        end

        function tArrayOfObjects(test)
            itemObj = struct("type", "object", ...
                "properties", struct("name", struct("type", "string"), ...
                                      "age", struct("type", "integer")), ...
                "required", {{'name'}});
            arr = struct("type", "array", "minItems", 2, "maxItems", 3);
            arr.items = itemObj;
            % 2..3 array length * 1..2 items each.
            test.verifyCount(arr, 2, 6);
        end

        function tTupleItems(test)
            % items as a cell array of positional schemas.
            tup = struct("type", "array");
            tup.items = {struct("type", "string"), struct("type", "integer")};
            test.verifyCount(tup, 2, 2);
        end

        function tTupleWithAdditionalItems(test)
            tup = struct("type", "array");
            tup.items = {struct("type", "string")};
            tupTrue = tup; tupTrue.additionalItems = true;
            test.verifyCount(tupTrue, 1, Inf);
            tupSchema = tup; tupSchema.additionalItems = struct("type", "number");
            test.verifyCount(tupSchema, 1, Inf);
        end

        function tOneOfUnion(test)
            % Union takes min of mins, max of maxes.
            un.oneOf = {struct("type", "string"), ...
                struct("type", "object", ...
                    "properties", struct("a", struct("type", "string"), ...
                                          "b", struct("type", "integer")))};
            test.verifyCount(un, 0, 2);
        end

        function tAnyOfUnion(test)
            un.anyOf = {struct("type", "string"), struct("type", "integer")};
            test.verifyCount(un, 1, 1);
        end

        function tEmptyUnionUnbounded(test)
            eo.oneOf = {};
            test.verifyCount(eo, 0, Inf);
        end

        function tAllOf(test)
            % allOf takes max of mins and max of maxes.
            al.allOf = {struct("type", "string"), ...
                struct("type", "object", ...
                    "properties", struct("a", struct("type", "string")), ...
                    "required", {{'a'}})};
            test.verifyCount(al, 1, 1);
        end

        function tEmptyAllOfUnbounded(test)
            ea.allOf = {};
            test.verifyCount(ea, 0, Inf);
        end

        function tPropertiesWithoutTypeIsObject(test)
            np = struct("properties", struct("a", struct("type", "string")));
            test.verifyCount(np, 0, 1);
        end

        function tItemsWithoutTypeIsArray(test)
            ni = struct();
            ni.items = struct("type", "number");
            test.verifyCount(ni, 0, Inf);
        end

        function tUnknownSchemaUnbounded(test)
            test.verifyCount(struct("foo", 1), 0, Inf);
        end

        function tWireEncodingWrapper(test)
            % The wrapper delegates to its properties.data schema.
            wrap.annotation = "Invertible wire encoding wrapper for MCP " + ...
                "Framework for MATLAB Production Server";
            wrap.properties.data = struct("type", "array", ...
                "items", struct("type", "number"), "minItems", 3, "maxItems", 3);
            test.verifyCount(wrap, 3, 3);
        end

    end

end
