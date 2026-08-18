classdef tRemoveField < matlab.unittest.TestCase
% Test prodserver.mcp.internal.removeField (remove every occurrence of a field
% from a nested struct, at any nesting level).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tFlatRemoval(test)
            import prodserver.mcp.internal.removeField
            r = removeField(struct("a", 1, "b", 2), "a");
            test.verifyFalse(isfield(r, "a"));
            test.verifyTrue(isfield(r, "b"));
        end

        function tAbsentFieldUnchanged(test)
            % Removing a field that is not present leaves the struct intact.
            import prodserver.mcp.internal.removeField
            r = removeField(struct("x", 1), "a");
            test.verifyTrue(isfield(r, "x"));
        end

        function tStructArrayRemoval(test)
            import prodserver.mcp.internal.removeField
            s(1) = struct("a", 1, "b", 2);
            s(2) = struct("a", 3, "b", 4);
            r = removeField(s, "a");
            test.verifyFalse(isfield(r, "a"));
            test.verifyEqual([r.b], [2 4]);
        end

        function tNestedStructRemoval(test)
            import prodserver.mcp.internal.removeField
            s = struct("a", 1);
            s.b = struct("a", 2, "c", 3);
            r = removeField(s, "a");
            test.verifyFalse(isfield(r, "a"));
            test.verifyFalse(isfield(r.b, "a"));
            test.verifyTrue(isfield(r.b, "c"));
        end

    end

end
