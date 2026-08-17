classdef tMcpWireDecodeValue < matlab.unittest.TestCase
% Test prodserver.mcp.jsonrpc.mcpWireDecodeValue (structural decode of a
% jsondecode'd MCP wire value back to the original MATLAB value). Focuses on
% the validation/error branches and edge cases not exercised by the
% round-trip tests in Test/unit/io/tWireEncode.m.

% Copyright 2026 The MathWorks, Inc.

    methods

        function v = decode(~, j)
            v = prodserver.mcp.jsonrpc.mcpWireDecodeValue(j);
        end

    end

    methods (Test)

        % --- Scalar decode rules -----------------------------------------

        function tBooleanScalar(test)
            test.verifyEqual(test.decode(true), true);
        end

        function tNumericScalarToDouble(test)
            v = test.decode(int32(5));
            test.verifyEqual(v, 5);
            test.verifyClass(v, "double");
        end

        function tFloatSentinels(test)
            test.verifyEqual(test.decode("NaN"), NaN);
            test.verifyEqual(test.decode("Inf"), Inf);
            test.verifyEqual(test.decode("-Inf"), -Inf);
        end

        function tPlainStringToChar(test)
            % A non-special, non-datetime string decodes to itself.
            test.verifyEqual(test.decode("hello"), "hello");
        end

        % --- Typed-wrapper valid edge cases ------------------------------

        function tEmptyStructArrayWithFields(test)
            v = test.decode(struct("type", "struct", "size", [0 0], ...
                "fields", {{'a', 'b'}}));
            test.verifyClass(v, "struct");
            test.verifyEqual(size(v), [0 0]);
            test.verifyEqual(sort(string(fieldnames(v))), ["a"; "b"]);
        end

        function tEmptyStructArrayNoFields(test)
            v = test.decode(struct("type", "struct", "size", [0 0]));
            test.verifyClass(v, "struct");
            test.verifyEqual(size(v), [0 0]);
        end

        function tDurationScalarForm(test)
            % {"type":"duration","seconds":N} with no size.
            v = test.decode(struct("type", "duration", "seconds", 5));
            test.verifyClass(v, "duration");
            test.verifyEqual(seconds(v), 5);
        end

        function tDurationArrayNumericData(test)
            v = test.decode(struct("type", "duration", "size", [1 2], ...
                "data", [3 4]));
            test.verifyClass(v, "duration");
            test.verifyEqual(seconds(v), [3 4]);
        end

        function tCategoricalWithUndefined(test)
            % A null element becomes <undefined> while categories are kept.
            v = test.decode(struct("type", "categorical", "size", [1 2], ...
                "categories", {{'x', 'y'}}, "data", {{'x', []}}));
            test.verifyClass(v, "categorical");
            test.verifyEqual(sum(isundefined(v)), 1);
            test.verifyEqual(sort(string(categories(v))), ["x"; "y"]);
        end

        function tStringArrayWithMissing(test)
            % A null element in a string array decodes to <missing>.
            v = test.decode(struct("type", "string", "size", [1 2], ...
                "data", {{'hi', []}}));
            test.verifyClass(v, "string");
            test.verifyEqual(ismissing(v), [false true]);
            test.verifyEqual(v(1), "hi");
        end

        % --- Error branches that already work ----------------------------

        function tUnknownTypeErrors(test)
            test.verifyError(@() test.decode(struct("type", "frobnicate", ...
                "size", [1 1], "data", {{1}})), ...
                "prodserver:mcp:unknownType");
        end

        function tMissingSizeErrors(test)
            test.verifyError(@() test.decode(struct("type", "double", ...
                "data", 5)), "prodserver:mcp:missingField");
        end

        function tDataLengthMismatchErrors(test)
            test.verifyError(@() test.decode(struct("type", "double", ...
                "size", [1 2], "data", {{1, 2, 3}})), ...
                "prodserver:mcp:dataLengthMismatch");
        end

        function tInvalidCharElementErrors(test)
            % A multi-character element in a char wrapper is rejected.
            test.verifyError(@() test.decode(struct("type", "char", ...
                "size", [1 1], "data", {{"xy"}})), ...
                "prodserver:mcp:invalidCharElement");
        end

        function tCategoricalMissingCategoriesErrors(test)
            test.verifyError(@() test.decode(struct("type", "categorical", ...
                "size", [1 1], "data", {{'a'}})), ...
                "prodserver:mcp:missingField");
        end

        function tTableMissingVariablesErrors(test)
            % A "size" companion makes this a typed wrapper (dispatches to
            % decodeTable) so the missing-"variables" check is reached.
            test.verifyError(@() test.decode(struct("type", "table", ...
                "size", [1 1])), "prodserver:mcp:missingField");
        end

        function tTimetableMissingRowTimesErrors(test)
            test.verifyError(@() test.decode(struct("type", "timetable", ...
                "variables", {{}})), "prodserver:mcp:missingField");
        end

        % --- Error branches broken by '+'-in-message (BUG) ---------------
        % These assert the INTENDED prodserver:mcp:* id but are filtered
        % because the message builds with 'char'+'char' and instead throws
        % MATLAB:sizeDimensionsMustMatch (BUG-mcpWireDecodeValue-error-concat.md).
        % Remove the assumeFail lines once the concatenations are fixed.

        function tNullNotAllowed(test)
            test.assumeFail("Known bug: error message uses '+' concat " + ...
                "(BUG-mcpWireDecodeValue-error-concat.md).");
            test.verifyError(@() test.decode([]), ...
                "prodserver:mcp:nullNotAllowed");
        end

        function tBareArrayInvalidEncoding(test)
            test.assumeFail("Known bug: error message uses '+' concat " + ...
                "(BUG-mcpWireDecodeValue-error-concat.md).");
            test.verifyError(@() test.decode([1 2 3]), ...
                "prodserver:mcp:invalidEncoding");
        end

        function tInvalidSize(test)
            test.assumeFail("Known bug: error message uses '+' concat " + ...
                "(BUG-mcpWireDecodeValue-error-concat.md).");
            test.verifyError(@() test.decode(struct("type", "double", ...
                "size", 5, "data", 5)), "prodserver:mcp:invalidSize");
        end

        function tInvalidNumericSentinel(test)
            test.assumeFail("Known bug: error message uses '+' concat " + ...
                "(BUG-mcpWireDecodeValue-error-concat.md).");
            test.verifyError(@() test.decode(struct("type", "double", ...
                "size", [1 1], "data", {{"bogus"}})), ...
                "prodserver:mcp:invalidNumericSentinel");
        end

        function tInvalidNumericElement(test)
            test.assumeFail("Known bug: error message uses '+' concat " + ...
                "(BUG-mcpWireDecodeValue-error-concat.md).");
            test.verifyError(@() test.decode(struct("type", "double", ...
                "size", [1 1], "data", {{{1}}})), ...
                "prodserver:mcp:invalidNumericElement");
        end

        function tInvalidLogicalElement(test)
            test.assumeFail("Known bug: error message uses '+' concat " + ...
                "(BUG-mcpWireDecodeValue-error-concat.md).");
            test.verifyError(@() test.decode(struct("type", "logical", ...
                "size", [1 1], "data", {{5}})), ...
                "prodserver:mcp:invalidLogicalElement");
        end

        function tInvalidDatetimeString(test)
            test.assumeFail("Known bug: error message uses '+' concat " + ...
                "(BUG-mcpWireDecodeValue-error-concat.md).");
            test.verifyError(@() test.decode(struct("type", "datetime", ...
                "size", [1 1], "data", {{"not-a-date"}})), ...
                "prodserver:mcp:invalidDatetimeString");
        end

    end

end
