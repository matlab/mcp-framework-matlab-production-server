classdef tAvailableList < matlab.unittest.TestCase
% Test prodserver.mcp.internal.availableList: what a server has, for the
% UnknownTool and UnknownResource errors of call and read.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function noneIsSaid(test)
            f = @prodserver.mcp.internal.availableList;
            test.verifyEqual(f("tools", string.empty), "It has no tools.");
            test.verifyEqual(f("resources", []), "It has no resources.", ...
                "As call gives it for a server with no tools: [].");
        end

        function namesAreSortedOnce(test)
            f = @prodserver.mcp.internal.availableList;
            test.verifyEqual(f("tools", ["b"; "a"; "b"]), "Its tools are: a, b.", ...
                "Sorted, a duplicate shown once, a column as a row.");
            test.verifyEqual(f("tools", "only"), "Its tools are: only.");
        end

        function manyAreCutAtTen(test)
            % A server with many doesn't fill the Command Window.
            names = "t" + compose("%02d", (12:-1:1)');
            txt = prodserver.mcp.internal.availableList("tools", names);
            test.verifyEqual(txt, "Its tools are: " + ...
                strjoin("t" + compose("%02d", (1:10)'), ", ") + ", and 2 more.");
            exactly = prodserver.mcp.internal.availableList("tools", names(3:end));
            test.verifyFalse(contains(exactly, "more"), "Ten are all shown.");
        end

    end
end
