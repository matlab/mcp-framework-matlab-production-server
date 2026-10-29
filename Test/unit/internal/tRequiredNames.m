classdef tRequiredNames < matlab.unittest.TestCase
% Test prodserver.mcp.internal.requiredNames: every shape a decoded schema's
% 'required' member can take gives a 1xN string.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        schema = {"inputSchema", "outputSchema"}
    end

    methods (Test)

        function listIsReturnedInOrder(test, schema)
            def.(schema) = jsondecode('{"required":["b","a","c"]}');
            test.verifyEqual(prodserver.mcp.internal.requiredNames(def, schema), ...
                ["b" "a" "c"]);
        end

        function singleNameIsARow(test, schema)
            def.(schema).required = 'x';
            test.verifyEqual(prodserver.mcp.internal.requiredNames(def, schema), "x");
        end

        function columnBecomesRow(test, schema)
            def.(schema).required = ["p"; "q"];
            test.verifyEqual(prodserver.mcp.internal.requiredNames(def, schema), ...
                ["p" "q"]);
        end

        function emptyShapesGiveEmptyRow(test, schema)
            % Absent key, absent schema, and "required":[] (XD18: a 0x0
            % double) all mean nothing is required.
            shapes = {struct(), struct(schema, struct()), ...
                struct(schema, jsondecode('{"required":[]}'))};
            for k = 1:numel(shapes)
                names = prodserver.mcp.internal.requiredNames(shapes{k}, schema);
                test.verifyClass(names, "string");
                test.verifySize(names, [1 0], sprintf("shape %d", k));
            end
        end

        function schemaFormReadsTheSchemaItself(test)
            % The nested-schema readers (argument validation, item counting)
            % hold a schema, not a tool definition.
            s = jsondecode('{"type":"object","required":["a","b"]}');
            test.verifyEqual(prodserver.mcp.internal.requiredNames(s), ...
                ["a" "b"]);
            test.verifySize(prodserver.mcp.internal.requiredNames(struct()), [1 0]);
            test.verifySize(prodserver.mcp.internal.requiredNames("not a schema"), [1 0]);
        end

        function cellOfNamesIsAccepted(test, schema)
            def.(schema).required = {'a', 'b'};
            test.verifyEqual(prodserver.mcp.internal.requiredNames(def, schema), ...
                ["a" "b"]);
        end

        function nonTextIsInvalidSchema(test)
            test.verifyError(@() prodserver.mcp.internal.requiredNames( ...
                struct('required', [1 2])), "prodserver:mcp:InvalidSchema");
            test.verifyError(@() prodserver.mcp.internal.requiredNames( ...
                struct('required', {{1}})), "prodserver:mcp:InvalidSchema");
        end

        function unknownSchemaIsRejected(test)
            test.verifyError(@() prodserver.mcp.internal.requiredNames( ...
                struct(), "properties"), "MATLAB:validators:mustBeMember");
        end

    end
end
