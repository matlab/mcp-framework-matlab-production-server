classdef tHelpParameters < matlab.unittest.TestCase
% Test prodserver.mcp.internal.helpParameters: parameter descriptions in a
% function's help text.

% Copyright 2026 The MathWorks, Inc.

    methods (TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods
        function p = parameters(~, fcn)
            p = prodserver.mcp.internal.helpParameters( ...
                prodserver.mcp.internal.metafunction(fcn));
        end
    end

    methods (Test)

        function findsInputsAndOutputs(test)
            p = test.parameters("schemaHelpParams");
            test.verifyEqual([p.name], ["signal" "windowSize" "N" "out" "BBOX"]);
            test.verifyEqual(p(1).text, "samples to smooth");
            test.verifyEqual(p(1).lines, 1);
        end

        function joinsContinuationLines(test)
            % A more deeply indented line continues the description.
            p = test.parameters("schemaHelpParams");
            test.verifyEqual(p(2).text, "window length, in samples");
            test.verifyEqual(p(2).lines, [2 3]);
            test.verifyEqual(p(3).text, "iterations. Higher numbers smooth more.");
        end

        function nameMatchesWithoutCase(test)
            % OUT and bbox in the help text; out and BBOX declared. The
            % declared name is the one returned.
            p = test.parameters("schemaHelpParams");
            test.verifyEqual(p(4).name, "out");
            test.verifyEqual(p(4).text, "the smoothed signal");
            test.verifyEqual(p(5).name, "BBOX");
            test.verifyEqual(p(5).text, "a bounding box");
        end

        function otherWordsAreNotParameters(test)
            % "type: not a parameter" begins with no parameter's name.
            p = test.parameters("schemaHelpParams");
            test.verifyFalse(any(contains([p.text], "not a parameter")));
        end

        function noHelpTextNoParameters(test)
            p = test.parameters("schemaNoComments");
            test.verifyEmpty(p);
            test.verifyEqual(fieldnames(p), {'name'; 'text'; 'lines'});
        end

    end
end
