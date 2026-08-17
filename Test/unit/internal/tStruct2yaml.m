classdef tStruct2yaml < matlab.unittest.TestCase
% Test prodserver.mcp.internal.struct2yaml (convert a struct to a YAML string;
% non-struct scalars fall through to jsonencode).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tScalarFieldsToYaml(test)
            import prodserver.mcp.internal.struct2yaml
            y = struct2yaml(struct("name", "bob", "age", 3));
            test.verifyEqual(y, "name: ""bob""" + newline + "age: 3");
        end

        function tNonStructEncodesAsJson(test)
            % A non-struct leaf is emitted via jsonencode (returns a char row).
            import prodserver.mcp.internal.struct2yaml
            test.verifyEqual(struct2yaml("hello"), '"hello"');
            test.verifyEqual(struct2yaml(42), '42');
        end

        function tNestedStruct(test)
            import prodserver.mcp.internal.struct2yaml
            data = struct("outer", struct("inner", 1));
            y = struct2yaml(data);
            test.verifyTrue(contains(y, "outer:"));
            test.verifyTrue(contains(y, "inner: 1"));
        end

    end

end
