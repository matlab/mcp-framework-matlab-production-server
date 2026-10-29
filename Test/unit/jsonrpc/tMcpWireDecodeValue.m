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

        function v = roundTrip(test, x)
            j = jsondecode(jsonencode( ...
                prodserver.mcp.jsonrpc.mcpWireEncodeValue(x)));
            v = test.decode(j);
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

        function tMissingElementsAreNull(test)
            % A missing string or undefined categorical element is JSON
            % null, not [null] -- which a client checking outputs against
            % the schema's string items would reject.
            enc = @(x) string(jsonencode(prodserver.mcp.jsonrpc.mcpWireEncodeValue(x)));
            test.verifySubstring(enc(["a" missing]), """data"":[""a"",null]");
            test.verifySubstring(enc(string(missing)), """data"":[null]");
            test.verifySubstring(enc(categorical(["x" missing])), ...
                """data"":[""x"",null]");
        end

        function tStringScalarDataIsArray(test)
            % A wrapper's data is always an array, even of one string: so
            % the rules say, and so the published schema describes it. A
            % bare "data":"hello" would round-trip just the same, so only
            % the encoding shows it.
            e = string(jsonencode(prodserver.mcp.jsonrpc.mcpWireEncodeValue("hello")));
            test.verifyEqual(e, ...
                "{""type"":""string"",""size"":[1,1],""data"":[""hello""]}");
            test.verifyEqual(test.roundTrip("hello"), "hello");
            % The old form, from servers and clients before 1.6, still
            % decodes.
            test.verifyEqual(test.decode(jsondecode( ...
                '{"type":"string","size":[1,1],"data":"hello"}')), "hello");
        end

        function tMissingElementsRoundTrip(test)
            for x = {["a" missing], string(missing), ["a" "b"; missing "d"], ...
                    categorical(["x" "y" missing]), categorical(missing), ...
                    categorical(string([missing; missing])), ...
                    categorical(["lo" missing "hi"], ["lo" "hi"], Ordinal=true)}
                v = test.roundTrip(x{1});
                test.verifyClass(v, class(x{1}));
                test.verifySize(v, size(x{1}));
                test.verifyEqual(ismissing(v), ismissing(x{1}));
                test.verifyEqual(string(v(~ismissing(v))), ...
                    string(x{1}(~ismissing(x{1}))));
            end
            % An undefined categorical has no categories, sent as []:
            % decoding it used to raise.
            test.verifyTrue(isundefined(test.roundTrip(categorical(missing))));
        end

        function tNestedNullStillDecodes(test)
            % The form the encoder sent before: [null] for each missing
            % element.
            j = jsondecode('{"type":"string","size":[1,2],"data":["a",[null]]}');
            test.verifyEqual(ismissing(test.decode(j)), [false true]);
            j = jsondecode(['{"type":"categorical","size":[1,2],' ...
                '"categories":["x"],"data":["x",[null]]}']);
            test.verifyEqual(isundefined(test.decode(j)), [false true]);
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
        function tNullNotAllowed(test)
            test.verifyError(@() test.decode([]), ...
                "prodserver:mcp:nullNotAllowed");
        end

        function tBareArrayInvalidEncoding(test)
            test.verifyError(@() test.decode([1 2 3]), ...
                "prodserver:mcp:invalidEncoding");
        end

        function tInvalidSize(test)
            test.verifyError(@() test.decode(struct("type", "double", ...
                "size", 5, "data", 5)), "prodserver:mcp:invalidSize");
        end

        function tInvalidNumericSentinel(test)
            test.verifyError(@() test.decode(struct("type", "double", ...
                "size", [1 1], "data", {{"bogus"}})), ...
                "prodserver:mcp:invalidNumericSentinel");
        end

        function tInvalidNumericElement(test)
            test.verifyError(@() test.decode(struct("type", "double", ...
                "size", [1 1], "data", {{{1}}})), ...
                "prodserver:mcp:invalidNumericElement");
        end

        function tInvalidLogicalElement(test)
            test.verifyError(@() test.decode(struct("type", "logical", ...
                "size", [1 1], "data", {{5}})), ...
                "prodserver:mcp:invalidLogicalElement");
        end

        function tInvalidDatetimeString(test)
            test.verifyError(@() test.decode(struct("type", "datetime", ...
                "size", [1 1], "data", {{"not-a-date"}})), ...
                "prodserver:mcp:invalidDatetimeString");
        end

        % --- Datetime round trips ----------------------------------------

        function tZonedScalarDatetime(test)
            % A scalar in a named zone goes out wrapped, with tz, and comes
            % back in that zone, not just at its offset.
            for z = ["America/New_York" "Europe/London" "+05:30"]
                d = datetime(2026,1,2,3,4,5, TimeZone=z);
                j = prodserver.mcp.jsonrpc.mcpWireEncodeValue(d);
                test.verifyEqual(j.tz, char(z), z);
                v = test.roundTrip(d);
                test.verifyEqual(v.TimeZone, char(z), z);
                test.verifyEqual(v, d, z);
            end
        end

        function tTextThatReadsAsAnotherValue(test)
            % A char row the decoder would read as a date-time, a special
            % float or NaT is wrapped, so it comes back as the same text.
            for t = {'2026-01-02', '2026-01-02T03:04', 'NaN', 'Inf', '-Inf', 'NaT'}
                j = prodserver.mcp.jsonrpc.mcpWireEncodeValue(t{1});
                test.verifyTrue(isstruct(j), t{1});
                test.verifyEqual(test.roundTrip(t{1}), t{1}, t{1});
            end
            % Ordinary text is still bare.
            test.verifyEqual(prodserver.mcp.jsonrpc.mcpWireEncodeValue('hello'), "hello");
            test.verifyEqual(test.roundTrip({'2026-01-02', 'x'}), {'2026-01-02', 'x'});
        end

        function tUTCAndUnzonedScalarDatetime(test)
            d = datetime(2026,1,2,3,4,5.25, TimeZone="UTC");
            test.verifyEqual(test.roundTrip(d), d);
            d.TimeZone = "";
            v = test.roundTrip(d);
            test.verifyEqual(v, d);
            test.verifyEmpty(v.TimeZone);
        end

        function tZonedDatetimeArrayKeepsZone(test)
            d = datetime(2026,1,2,3,4,5, TimeZone="America/New_York") ...
                + days([0 1; 2 3]);
            d(2,1) = NaT;
            v = test.roundTrip(d);
            test.verifyEqual(v.TimeZone, 'America/New_York');
            test.verifyEqual(isnat(v), isnat(d));
            test.verifyEqual(v(~isnat(v)), d(~isnat(d)));
        end

        function tSubMillisecondDatetime(test)
            % The invertible encoding keeps every digit a datetime holds.
            d = datetime(2026,1,2,3,4,5, TimeZone="UTC") + ...
                seconds([0.000123456 0.5]);
            % (A datetime comparison takes no tolerance.)
            v = test.roundTrip(d);
            test.verifyEqual(seconds(v - d), [0 0], AbsTol=1e-9);
            test.verifyEqual(seconds(test.roundTrip(d(1)) - d(1)), 0, AbsTol=1e-9);
        end

        function tCalendarDurationErrors(test)
            test.verifyError(@() prodserver.mcp.jsonrpc.mcpWireEncodeValue( ...
                calmonths(1)), "prodserver:mcp:unsupportedDurationType");
        end

    end

end
