classdef tParseISODateTime < matlab.unittest.TestCase
% Test prodserver.mcp.jsonrpc.parseISODateTime: strict ISO 8601, the forms
% plainJSONValue writes, and nothing MATLAB would have to guess at.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function acceptedForms(test)
            P = @prodserver.mcp.jsonrpc.parseISODateTime;
            cases = {
                "2026-01-02",                    datetime(2026,1,2),             ""
                "2026-01-02T03:04",              datetime(2026,1,2,3,4,0),       ""
                "2026-01-02T03:04:05",           datetime(2026,1,2,3,4,5),       ""
                "2026-01-02T03:04:05.250",       datetime(2026,1,2,3,4,5.25),    ""
                "2026-01-02T03:04:05.250Z",      datetime(2026,1,2,3,4,5.25),    "UTC"
                "2026-01-02T03:04:05-05:00",     datetime(2026,1,2,3,4,5),       "-05:00"
                "2026-01-02T03:04+05:30",        datetime(2026,1,2,3,4,0),       "+05:30"
                };
            for k = 1:size(cases, 1)
                [d, ok] = P(cases{k,1});
                test.verifyTrue(ok, cases{k,1});
                test.verifyEqual(d.TimeZone, char(cases{k,3}), cases{k,1});
                expected = cases{k,2};
                expected.TimeZone = cases{k,3};
                test.verifyEqual(d, expected, cases{k,1});
            end
        end

        function rejectedForms(test)
            % Locale-dependent, nonexistent or malformed: not guessed at.
            for t = ["01/02/2026", "02-Jan-2026", "2026-1-2", "2026-02-30", ...
                    "2026-13-01", "2026-01-02T24:00", "2026-01-02T03:60", ...
                    "2026-01-02Z", "2026-01-02T03:04:05+5:00", "", "now"]
                [d, ok] = prodserver.mcp.jsonrpc.parseISODateTime(t);
                test.verifyFalse(ok, t);
                test.verifyTrue(isnat(d), t);
            end
            [~, ok] = prodserver.mcp.jsonrpc.parseISODateTime(7);
            test.verifyFalse(ok, "a number");
        end

        function readsWhatPlainJSONValueWrites(test)
            for c = {datetime(2026,1,2,3,4,5.25), ...
                    datetime(2026,1,2,3,4,5, TimeZone="UTC")}
                d = c{1};
                text = prodserver.mcp.jsonrpc.plainJSONValue(d);
                [back, ok] = prodserver.mcp.jsonrpc.parseISODateTime(text);
                test.verifyTrue(ok, text);
                test.verifyEqual(back, d, text);
            end
            % A named zone comes back as its offset: the same instant.
            d = datetime(2026,1,2,3,4,5, TimeZone="America/New_York");
            [back, ok] = prodserver.mcp.jsonrpc.parseISODateTime( ...
                prodserver.mcp.jsonrpc.plainJSONValue(d));
            test.verifyTrue(ok);
            test.verifyEqual(back.TimeZone, '-05:00');
            test.verifyEqual(datetime(back, TimeZone="UTC"), ...
                datetime(d, TimeZone="UTC"));
        end

        function yearsBeyondFourDigits(test)
            % Written with uuuu, so year 0 and before keep their sign.
            for y = [-5 0 10000]
                d = datetime(y, 1, 2, 3, 4, 5, TimeZone="UTC");
                text = prodserver.mcp.jsonrpc.isoDateTimeText(d);
                [back, ok] = prodserver.mcp.jsonrpc.parseISODateTime(text);
                test.verifyTrue(ok, text);
                test.verifyEqual(back, d, text);
            end
            test.verifyEqual(prodserver.mcp.jsonrpc.isoDateTimeText( ...
                datetime(-5,1,2)), "-0005-01-02T00:00:00.000");
        end

        function wholeArrays(test)
            % One call for an array: its size, each element's zone.
            P = @prodserver.mcp.jsonrpc.parseISODateTime;
            [d, ok, zone] = P(["2026-01-01T00:00Z" "nope"; ...
                "2026-01-02T00:00Z" "2026-01-03T00:00+00:00"]);
            test.verifySize(d, [2 2]);
            test.verifyEqual(ok, [true false; true true]);
            test.verifyEqual(zone, ["UTC" missing; "UTC" "+00:00"]);
            test.verifyTrue(isnat(d(1,2)));
            % Different zones: the same instants, in UTC.
            [d, ~, zone] = P(["2026-01-01T12:00-05:00" "2026-06-30T12:00-04:00"]);
            test.verifyEqual(d.TimeZone, 'UTC');
            test.verifyEqual(d, datetime(2026, [1 6], [1 30], [17 16], 0, 0, ...
                TimeZone="UTC"));
            test.verifyEqual(zone, ["-05:00" "-04:00"]);
            % Zoned and unzoned: no one zone, so NaT; zone says why.
            [d, ok, zone] = P({'2026-01-01T00:00Z', '2026-01-02', []});
            test.verifyEqual(ok, [true true false]);
            test.verifyTrue(all(isnat(d)));
            test.verifyEqual(zone(1:2), ["UTC" ""]);
        end

        function lowerCaseTAndZ(test)
            % RFC 3339 allows them.
            [d, ok] = prodserver.mcp.jsonrpc.parseISODateTime("2026-01-02t03:04:05z");
            test.verifyTrue(ok);
            test.verifyEqual(d, datetime(2026,1,2,3,4,5, TimeZone="UTC"));
        end

        function subMillisecondPrecision(test)
            % Written with as many digits as it needs; read back exactly.
            d = datetime(2026,1,2,3,4,5, TimeZone="UTC") + seconds(0.000123456);
            text = prodserver.mcp.jsonrpc.isoDateTimeText(d);
            test.verifyEqual(text, "2026-01-02T03:04:05.000123456Z");
            back = prodserver.mcp.jsonrpc.parseISODateTime(text);
            test.verifyEqual(seconds(back - d), 0, AbsTol=1e-9);
            % Whole milliseconds keep the usual three places.
            test.verifyEqual(prodserver.mcp.jsonrpc.isoDateTimeText( ...
                datetime(2026,1,2,3,4,5.25)), "2026-01-02T03:04:05.250");
            test.verifyEqual(prodserver.mcp.jsonrpc.isoDateTimeText( ...
                datetime(2026,1,2,3,4,5, TimeZone="Asia/Kolkata") + ...
                seconds(0.0005)), "2026-01-02T03:04:05.0005+05:30");
        end

    end
end
