classdef tDecodeJSONValues < matlab.unittest.TestCase
% Test prodserver.mcp.jsonrpc.decodeJSONValues: under plain JSON, the
% schema says which arguments are datetimes (format "date-time") and
% durations (x-matlab-class "duration"), at any depth.

% Copyright 2026 The MathWorks, Inc.

    properties
        tool
    end

    methods (TestMethodSetup)
        function makeTool(test)
            import prodserver.mcp.jsonrpc.WireShape
            dt = prodserver.mcp.jsonrpc.jsonTimeSchema("datetime", WireShape.Scalar);
            du = prodserver.mcp.jsonrpc.jsonTimeSchema("duration", WireShape.Scalar);
            p.when = dt;
            p.gap = du;
            p.times = prodserver.mcp.jsonrpc.jsonTimeSchema("datetime", WireShape.Array);
            p.gaps = prodserver.mcp.jsonrpc.jsonTimeSchema("duration", WireShape.Array);
            p.rec = struct('type', "object", 'properties', ...
                struct('when', dt, 'n', struct('type', "number")));
            p.recs = struct('type', "array", 'items', p.rec);
            p.label = struct('type', "string");
            % As the example path writes a parameter seen with two classes.
            p.either = struct('anyOf', {{dt, struct('type', "number")}});
            p.textOrTime = struct('oneOf', {{struct('type', "string"), dt}});
            test.tool = struct('name', "t", ...
                'inputSchema', struct('type', "object", 'properties', p));
        end
    end

    methods
        function [args, msg] = decode(test, json)
            [args, msg] = prodserver.mcp.jsonrpc.decodeJSONValues( ...
                test.tool.inputSchema, jsondecode(json), "Argument");
        end
    end

    methods (Test)

        function scalars(test)
            [a, msg] = test.decode('{"when":"2026-01-02T03:04:05Z","gap":90}');
            test.verifyEqual(msg, "");
            test.verifyEqual(a.when, datetime(2026,1,2,3,4,5, TimeZone="UTC"));
            test.verifyEqual(a.gap, seconds(90));
        end

        function nulls(test)
            [a, msg] = test.decode('{"when":null,"gap":null}');
            test.verifyEqual(msg, "");
            test.verifyTrue(isnat(a.when));
            test.verifyClass(a.gap, "duration");
            test.verifyTrue(isnan(seconds(a.gap)));
        end

        function arrays(test)
            [a, msg] = test.decode(['{"times":["2026-01-01","2026-01-02"],' ...
                '"gaps":[1,null,3]}']);
            test.verifyEqual(msg, "");
            test.verifyEqual(a.times, datetime(2026,1,1:2)');
            test.verifyEqual(seconds(a.gaps([1 3])), [1; 3]);
            test.verifyTrue(isnan(seconds(a.gaps(2))));
        end

        function singleValueForArray(test)
            % A MATLAB scalar is a 1x1 array.
            [a, msg] = test.decode('{"times":"2026-01-01"}');
            test.verifyEqual(msg, "");
            test.verifyEqual(a.times, datetime(2026,1,1));
        end

        function nullTakesNeighboursZone(test)
            [a, msg] = test.decode('{"times":["2026-01-01T00:00:00Z",null]}');
            test.verifyEqual(msg, "");
            test.verifyEqual(a.times.TimeZone, 'UTC');
            test.verifyTrue(isnat(a.times(2)));
        end

        function allNulls(test)
            % jsondecode makes a JSON array of nulls numeric NaN.
            [a, msg] = test.decode('{"times":[null,null,null]}');
            test.verifyEqual(msg, "");
            test.verifyClass(a.times, "datetime");
            test.verifySize(a.times, [3 1]);
            test.verifyTrue(all(isnat(a.times)));
        end

        function emptyArrays(test)
            % Under an array schema, [] is an empty array, not null.
            [a, msg] = test.decode('{"times":[],"gaps":[]}');
            test.verifyEqual(msg, "");
            test.verifyClass(a.times, "datetime");
            test.verifyEmpty(a.times);
            test.verifyClass(a.gaps, "duration");
            test.verifyEmpty(a.gaps);
        end

        function matrices(test)
            % Rows nest, row-major.
            [a, msg] = test.decode(['{"times":[["2026-01-01","2026-01-02","2026-01-03"],' ...
                '["2026-02-01",null,"2026-02-03"]],"gaps":[[1,2],[3,4]]}']);
            test.verifyEqual(msg, "");
            test.verifySize(a.times, [2 3]);
            test.verifyEqual(a.times(1,3), datetime(2026,1,3));
            test.verifyEqual(a.times(2,1), datetime(2026,2,1));
            test.verifyTrue(isnat(a.times(2,2)));
            test.verifyEqual(seconds(a.gaps), [1 2; 3 4]);
            % Rows of different lengths can't be a matrix.
            [~, msg] = test.decode('{"times":[["2026-01-01"],["2026-01-02","2026-01-03"]]}');
            test.verifySubstring(msg, "rows of equal length");
        end

        function messageForAnyValue(test)
            % Not text, so not quoted, and the message mustn't fail.
            [~, msg] = test.decode('{"when":[1,2]}');
            test.verifySubstring(msg, "got [1,2]");
            [~, msg] = test.decode('{"times":[1,null]}');
            test.verifySubstring(msg, "Argument 'times': expected");
        end

        function sameOffsetDifferentlyWritten(test)
            % Z, +00:00 and -00:00 are one offset.
            [a, msg] = test.decode(['{"times":["2026-01-01T00:00:00Z",' ...
                '"2026-01-02T00:00:00+00:00","2026-01-03T00:00:00-00:00"]}']);
            test.verifyEqual(msg, "");
            test.verifyEqual(datetime(a.times, TimeZone="UTC"), ...
                datetime(2026,1,1:3, TimeZone="UTC")');
        end

        function alternatives(test)
            [a, msg] = test.decode('{"either":"2026-01-02T03:04:05Z"}');
            test.verifyEqual(msg, "");
            test.verifyEqual(a.either, datetime(2026,1,2,3,4,5, TimeZone="UTC"));
            [a, msg] = test.decode('{"either":5}');
            test.verifyEqual(msg, "");
            test.verifyEqual(a.either, 5);
            % Text that is a date-time converts, whatever the order; other
            % text is the plain string it may be.
            [a, msg] = test.decode('{"textOrTime":"2026-01-02"}');
            test.verifyEqual(msg, "");
            test.verifyEqual(a.textOrTime, datetime(2026,1,2));
            [a, msg] = test.decode('{"textOrTime":"soon"}');
            test.verifyEqual(msg, "");
            test.verifyEqual(a.textOrTime, 'soon');
        end

        function nested(test)
            [a, msg] = test.decode(['{"rec":{"when":"2026-03-04","n":1},' ...
                '"recs":[{"when":"2026-03-05","n":2},{"when":"2026-03-06","n":3}]}']);
            test.verifyEqual(msg, "");
            test.verifyEqual(a.rec.when, datetime(2026,3,4));
            test.verifyEqual(a.rec.n, 1);
            test.verifyEqual(a.recs(2).when, datetime(2026,3,6));
        end

        function otherValuesUnchanged(test)
            [a, msg] = test.decode('{"label":"2026-01-02","extra":"2026-01-02"}');
            test.verifyEqual(msg, "");
            test.verifyEqual(a.label, '2026-01-02', "a plain string");
            test.verifyEqual(a.extra, '2026-01-02', "no schema at all");
        end

        function failures(test)
            cases = {
                '{"when":"01/02/2026"}',                 "Argument 'when': expected an ISO 8601 date-time"
                '{"times":["2026-01-01","nope"]}',       "Argument 'times(2)': expected"
                '{"rec":{"when":"March 4","n":1}}',      "Argument 'rec.when': expected"
                '{"times":["2026-01-01T00:00:00Z","2026-01-02"]}', ...
                    "Argument 'times': mixes date-times with and without a time zone"
                '{"times":["2026-01-01T00:00:00Z","2026-01-02T00:00:00-05:00"]}', ...
                    "Argument 'times': mixes time zones (+00:00, -05:00)"
                '{"either":"tomorrow"}',                 "Argument 'either': expected"
                };
            for k = 1:size(cases, 1)
                [~, msg] = test.decode(cases{k,1});
                test.verifySubstring(msg, cases{k,2}, cases{k,1});
            end
        end

    end
end
