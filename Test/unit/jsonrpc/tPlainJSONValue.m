classdef tPlainJSONValue < matlab.unittest.TestCase
% Test prodserver.mcp.jsonrpc.plainJSONValue: under plain JSON encoding, a
% datetime or duration in a tool output must not reach jsonencode, which
% writes them as locale-dependent display text (and a timetable as {}).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function datetimeIsISO8601(test)
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            d = datetime(2026,1,2,3,4,5);
            test.verifyEqual(P(d), "2026-01-02T03:04:05.000", "unzoned");
            d.TimeZone = "UTC";
            test.verifyEqual(P(d), "2026-01-02T03:04:05.000Z", "UTC");
            d = datetime(2026,1,2,3,4,5, TimeZone="America/New_York");
            test.verifyEqual(P(d), "2026-01-02T03:04:05.000-05:00", "zoned");
        end

        function zonedArrayIsUTC(test)
            % A named zone's offset changes with daylight saving; an array
            % is written in UTC so that it has one zone to be read back in.
            % Noon on 1 January (-05:00) and 30 June (-04:00).
            d = datetime(2026, [1 6], [1 30], 12, 0, 0, TimeZone="America/New_York");
            v = prodserver.mcp.jsonrpc.plainJSONValue(d);
            test.verifyEqual(v, ["2026-01-01T17:00:00.000Z" "2026-06-30T16:00:00.000Z"]);
            % A scalar keeps its offset.
            test.verifyEqual(prodserver.mcp.jsonrpc.plainJSONValue(d(2)), ...
                "2026-06-30T12:00:00.000-04:00");
        end

        function zonedArrayReadsBack(test)
            % What the server writes, the client reads: same instants.
            d = datetime(2026,1,1,12,0,0, TimeZone="America/New_York") + days([0 180]);
            schema = struct('properties', struct('d', ...
                prodserver.mcp.jsonrpc.jsonTimeSchema("datetime")));
            sent = jsondecode(jsonencode(struct('d', ...
                prodserver.mcp.jsonrpc.plainJSONValue(d))));
            [back, msg] = prodserver.mcp.jsonrpc.decodeJSONValues(schema, sent, "Output");
            test.verifyEqual(msg, "");
            test.verifyEqual(datetime(back.d(:)', TimeZone="UTC"), ...
                datetime(d, TimeZone="UTC"));
        end

        function formatDoesNotMatter(test)
            % The datetime's own display format is what jsonencode used.
            d = datetime(2026,1,2,3,4,5, Format="dd-MMM-yyyy");
            test.verifyEqual(prodserver.mcp.jsonrpc.plainJSONValue(d), ...
                "2026-01-02T03:04:05.000");
        end

        function datetimeArrayKeepsShapeAndNaTIsNull(test)
            d = [datetime(2026,1,1); NaT; datetime(2026,1,3)];
            v = prodserver.mcp.jsonrpc.plainJSONValue(d);
            test.verifySize(v, [3 1]);
            test.verifyEqual(jsonencode(v), ...
                '["2026-01-01T00:00:00.000",null,"2026-01-03T00:00:00.000"]');
        end

        function durationIsSeconds(test)
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            test.verifyEqual(P(minutes(90)), 5400);
            test.verifyEqual(P([seconds(1) hours(1)]), [1 3600]);
        end

        function nestedValuesConverted(test)
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            d = datetime(2026,1,2,3,4,5);
            iso = "2026-01-02T03:04:05.000";

            s = P(struct('when', d, 'n', 2));
            test.verifyEqual(s.when, iso, "struct field");
            test.verifyEqual(s.n, 2, "other fields unchanged");

            s = P([struct('when', d); struct('when', d + days(1))]);
            test.verifyEqual(s(2).when, "2026-01-03T03:04:05.000", "struct array");

            c = P({2, d, {minutes(1)}});
            test.verifyEqual(c{2}, iso, "cell");
            test.verifyEqual(c{3}{1}, 60, "nested cell");

            t = P(table(d, minutes(2), VariableNames=["when", "span"]));
            test.verifyEqual(t.when, iso, "table variable");
            test.verifyEqual(t.span, 120, "table duration");
        end

        function timetableKeepsItsData(test)
            % jsonencode writes a timetable as {}: every value is lost.
            tt = timetable(datetime(2026,1,1:2)', [10; 20], VariableNames="v");
            v = prodserver.mcp.jsonrpc.plainJSONValue(tt);
            test.verifyEqual(jsonencode(v), ['[{"Time":"2026-01-01T00:00:00.000","v":10},' ...
                '{"Time":"2026-01-02T00:00:00.000","v":20}]']);
        end

        function otherValuesUnchanged(test)
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            values = {3.14, [1 2; 3 4], "text", 'chars', true, ...
                struct('a', 1, 'b', "x"), {1, "two"}, ...
                table([1; 2], VariableNames="x"), categorical("lo"), int8(5)};
            for k = 1:numel(values)
                test.verifyEqual(P(values{k}), values{k}, class(values{k}));
            end
        end

        function mcpEncodeAppliesItUnderJSONOnly(test)
            d = datetime(2026,1,2,3,4,5);
            out = prodserver.mcp.jsonrpc.mcpEncode( ...
                prodserver.mcp.WireEncoding.JSON, d, 7);
            test.verifyEqual(out, {"2026-01-02T03:04:05.000", 7});
            % Invertible has its own form for a datetime: unchanged here.
            out = prodserver.mcp.jsonrpc.mcpEncode( ...
                prodserver.mcp.WireEncoding.Invertible, d);
            test.verifyEqual(out{1}, ...
                prodserver.mcp.jsonrpc.mcpWireEncodeValue(d));
        end

    end
end
