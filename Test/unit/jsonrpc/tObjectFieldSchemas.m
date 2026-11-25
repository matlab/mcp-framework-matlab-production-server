classdef tObjectFieldSchemas < matlab.unittest.TestCase
%tObjectFieldSchemas Verify the schemas a struct's fields have under a
%schema, with and without alternatives.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function oneSchema(test)
            % Its properties, or its items': as plainJSONValue had them.
            F = @prodserver.mcp.jsonrpc.objectFieldSchemas;
            num = struct('type', "number");
            obj = struct('type', "object", 'properties', struct('a', num));
            test.verifyEqual(F(obj), struct('a', num));
            test.verifyEqual(F(struct('type', "array", 'items', obj)), ...
                struct('a', num), "an array of structs");
            test.verifyEqual(F(num), struct(), "not a struct's");
            test.verifyEqual(F([]), struct(), "no schema");
            test.verifyEqual(F(struct('type', "array", 'items', num)), struct());
        end

        function alternatives(test)
            % Every field any alternative describes, by the one schema they
            % give it, or an anyOf of the different ones.
            F = @prodserver.mcp.jsonrpc.objectFieldSchemas;
            num = struct('type', "number");
            nums = struct('type', "array", 'items', num);
            text = struct('type', "string");
            a = struct('type', "object", 'properties', struct('a', num));
            ab = struct('type', "object", 'properties', struct('a', num, 'b', text));
            aArray = struct('type', "object", 'properties', struct('a', nums));
            f = F(struct('anyOf', {{a, ab}}));
            test.verifyEqual(f, struct('a', num, 'b', text), "the same a, once");
            f = F(struct('anyOf', {{struct('type', "array", 'items', a), ab}}));
            test.verifyEqual(f, struct('a', num, 'b', text), "an array's items too");
            f = F(struct('anyOf', {{a, aArray}}));
            test.verifyEqual(f.a.anyOf(:), {num; nums}, "a in two shapes");
            f = F(struct('oneOf', {{ab, num}}));
            test.verifyEqual(f, struct('a', num, 'b', text), "oneOf, beside a number");
            f = F(struct('type', "array", 'items', struct('anyOf', {{a, ab}})));
            test.verifyEqual(f, struct('a', num, 'b', text), "items with alternatives");
            test.verifyEqual(F(struct('anyOf', {{num, text}})), struct(), "no structs");
        end

        function byTheValuesShape(test)
            % Given the struct, the fields of the alternatives that fit its
            % shape; a field none of them describes, as the others give it.
            F = @prodserver.mcp.jsonrpc.objectFieldSchemas;
            num = struct('type', "number");
            nums = struct('type', "array", 'items', num);
            text = struct('type', "string");
            obj = @(p) struct('type', "object", 'properties', p);
            s = struct('anyOf', {{struct('type', "array", 'items', obj(struct('a', num))), ...
                obj(struct('a', nums, 'b', text))}});
            test.verifyEqual(F(s, struct('a', 1)), struct('a', nums, 'b', text), "one struct");
            test.verifyEqual(F(s, struct('a', {1, 2})), struct('a', num, 'b', text), ...
                "a struct array: b from the other");
            test.verifyEqual(F(s, struct('a', {})), struct('a', num, 'b', text), "empty");
            test.verifyEqual(F(s).a.anyOf(:), {num; nums}, "without a value, merged");
            % With none that fits, every alternative's.
            o = struct('anyOf', {{obj(struct('a', num)), obj(struct('a', text))}});
            test.verifyEqual(F(o, struct('a', {1, 2})).a.anyOf(:), {num; text});
            test.verifyEqual(F(obj(struct('a', num)), struct('a', 1)), struct('a', num), ...
                "no alternatives");
            % Of those, the ones its fields can satisfy: one that requires
            % a field it lacks, or forbids one it has, isn't its.
            ab = obj(struct('a', num, 'b', num));
            ab.required = ["a"; "b"];
            aList = obj(struct('a', nums));
            aList.required = "a";
            r = struct('anyOf', {{ab, aList}});
            test.verifyEqual(F(r, struct('a', 7)), struct('a', nums, 'b', num), ...
                "it lacks b: the second's a");
            test.verifyEqual(F(r, struct('a', 7, 'b', 2)).a.anyOf(:), {num; nums}, ...
                "it may be either");
            closed = aList;
            closed.additionalProperties = false;
            c = struct('anyOf', {{obj(struct('a', num)), closed}});
            test.verifyEqual(F(c, struct('a', 7, 'b', 2)), struct('a', num), ...
                "the second forbids b");
        end

        function mayHoldStruct(test)
            % Whether a struct with these fields may satisfy a schema: it
            % has each required one, and none it forbids.
            H = @prodserver.mcp.jsonrpc.mayHoldStruct;
            num = struct('type', "number");
            obj = struct('type', "object", 'properties', struct('a', num, 'b', num));
            test.verifyTrue(H(obj, "a"), "nothing required");
            obj.required = ["a"; "b"];
            test.verifyFalse(H(obj, "a"), "b is required");
            test.verifyTrue(H(obj, ["a" "b"]));
            test.verifyTrue(H(obj, ["a" "b" "c"]), "others allowed");
            obj.additionalProperties = false;
            test.verifyFalse(H(obj, ["a" "b" "c"]), "c is forbidden");
            test.verifyTrue(H(struct('type', "array", 'items', obj), ["a" "b"]), ...
                "an array's items");
            test.verifyFalse(H(struct('type', "array", 'items', obj), "a"));
            test.verifyFalse(H(num, "a"), "a number");
            test.verifyFalse(H(struct('type', "array", 'items', num), "a"), ...
                "an array of numbers");
            test.verifyTrue(H(struct('required', "a"), "a"), "no type");
            test.verifyFalse(H([], "a"), "no schema");
        end

        function fieldsReadBackAsSent(test)
            % plainJSONValue writes each field by these schemas, and
            % decodeJSONValues reads it back by them, so an Inf in a field
            % one alternative describes arrives as Inf: under a %#schema
            % whose items list alternatives, it was a tool error.
            num = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(struct('type', "number"));
            a = struct('type', "object", 'properties', struct('a', num));
            ab = struct('type', "object", 'properties', struct('a', num, 'b', num));
            for s = {struct('type', "array", 'items', struct('anyOf', {{a, ab}})), ...
                    struct('anyOf', {{a, ab}})}
                os = struct('properties', struct('y', s{1}));
                v = struct('a', {1, Inf}, 'b', {-Inf, 2});
                j = jsonencode(struct('y', ...
                    {prodserver.mcp.jsonrpc.plainJSONValue(v, s{1})}));
                b = prodserver.mcp.jsonrpc.decodeJSONValues(os, jsondecode(j), "Output");
                test.verifyEqual(b.y, v(:), j);
            end
        end

    end
end
