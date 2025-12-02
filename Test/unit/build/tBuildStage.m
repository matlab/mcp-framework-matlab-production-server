classdef tBuildStage < matlab.unittest.TestCase
    methods(Test)

        function lessThan(test)
        % Test relational operator less-than.

            s0 = prodserver.mcp.BuildStage.Wrapper;
            s1 = prodserver.mcp.BuildStage.Deploy;
            test.verifyTrue(s0 < s1, "Wrapper < Deploy");

            s1 = [ prodserver.mcp.BuildStage.Archive, ...
                prodserver.mcp.BuildStage.Definition, ...
                prodserver.mcp.BuildStage.Deploy, ...
                prodserver.mcp.BuildStage.Routes];
            test.verifyTrue(all(s0 < s1), "Wrapper < All others");

            s0 = [ prodserver.mcp.BuildStage.Wrapper, ...
                prodserver.mcp.BuildStage.Definition ];
            s1 = [ prodserver.mcp.BuildStage.Archive, ...
                prodserver.mcp.BuildStage.Routes];
            test.verifyTrue(all(s0 < s1), "Wrapper + Definition < Archive + Routes");

            s0 = [ prodserver.mcp.BuildStage.Wrapper, ...
                prodserver.mcp.BuildStage.Routes ];
            s1 = [ prodserver.mcp.BuildStage.Archive, ...
                prodserver.mcp.BuildStage.Definition];
            test.verifyEqual(s0 < s1, [true, false], "Interleaved");

        end

        function greaterThan(test)
        % Test relational operator greater-than.

            s0 = prodserver.mcp.BuildStage.Deploy;
            s1 = prodserver.mcp.BuildStage.Wrapper;
            test.verifyTrue(s0 > s1, "Deploy > Wrapper");

            s1 = [ prodserver.mcp.BuildStage.Wrapper, ...
                prodserver.mcp.BuildStage.Archive, ...
                prodserver.mcp.BuildStage.Definition, ...
                prodserver.mcp.BuildStage.Routes];
            test.verifyTrue(all(s0 > s1), "Deploy > All others");

            s0 = [ prodserver.mcp.BuildStage.Archive, ...
                prodserver.mcp.BuildStage.Routes];
            s1 = [ prodserver.mcp.BuildStage.Wrapper, ...
                prodserver.mcp.BuildStage.Definition ];
            test.verifyTrue(all(s0 > s1), "Archive + Routes > Wrapper + Definition");

            s0 = [ prodserver.mcp.BuildStage.Wrapper, ...
                prodserver.mcp.BuildStage.Routes ];
            s1 = [ prodserver.mcp.BuildStage.Archive, ...
                prodserver.mcp.BuildStage.Definition];
            test.verifyEqual(s0 > s1, [false, true], "Interleaved");

        end

        function greaterEqual(test)
        % Test relational operator greater-than-or-equal-to.

            s0 = prodserver.mcp.BuildStage.Archive;
            s1 = prodserver.mcp.BuildStage.Wrapper;
            test.verifyTrue(s0 >= s1, "Archive >= Wrapper");

            s0 = prodserver.mcp.BuildStage.Deploy;
            s1 = [ prodserver.mcp.BuildStage.Wrapper, ...
                prodserver.mcp.BuildStage.Definition, ...
                prodserver.mcp.BuildStage.Archive, ...
                prodserver.mcp.BuildStage.Deploy, ...
                prodserver.mcp.BuildStage.Routes];
            test.verifyTrue(all(s0 >= s1), "Deploy > All others");

            s0 = [ prodserver.mcp.BuildStage.Archive, ...
                prodserver.mcp.BuildStage.Routes];
            s1 = [ prodserver.mcp.BuildStage.Wrapper, ...
                prodserver.mcp.BuildStage.Definition ];
            test.verifyTrue(all(s0 >= s1), "Archive + Routes >= Wrapper + Definition");

            s0 = [ prodserver.mcp.BuildStage.Wrapper, ...
                prodserver.mcp.BuildStage.Routes ];
            s1 = [ prodserver.mcp.BuildStage.Archive, ...
                prodserver.mcp.BuildStage.Definition];
            test.verifyEqual(s0 >= s1, [false, true], "Interleaved");

            s0 = prodserver.mcp.BuildStage.Order;
            s1 = flip(s0);
            test.verifyEqual(s0 >= s1, [false, false, true, true, true], ...
                "Reversed");

            s0 = prodserver.mcp.BuildStage.Order;
            s1 = s0;
            test.verifyTrue(all(s0 >= s1), "Equal");
        end

        function lessEqual(test)
        % Test relational operator less-than-or-equal-to.

            s0 = prodserver.mcp.BuildStage.Wrapper;
            s1 = prodserver.mcp.BuildStage.Archive;
            test.verifyTrue(s0 <= s1, "Wrapper <= Archive");

            s0 = prodserver.mcp.BuildStage.Wrapper;
            s1 = [ prodserver.mcp.BuildStage.Deploy, ...
                prodserver.mcp.BuildStage.Wrapper, ...
                prodserver.mcp.BuildStage.Definition, ...
                prodserver.mcp.BuildStage.Archive, ...
                prodserver.mcp.BuildStage.Routes];
            test.verifyTrue(all(s0 <= s1), "Wrapper <= All others");

            s0 = prodserver.mcp.BuildStage.Order;
            s1 = flip(s0);
            test.verifyEqual(s0 <= s1, [true, true, true, false, false ], ...
                "Reversed");

            s0 = prodserver.mcp.BuildStage.Order;
            s1 = s0;
            test.verifyTrue(all(s0 <= s1), "Equal");
        end

    end
end