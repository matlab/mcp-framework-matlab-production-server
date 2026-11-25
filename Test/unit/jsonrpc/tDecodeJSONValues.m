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

        function nullableNumbers(test)
            % Plain JSON writes an output's scalar NaN as null, which
            % jsondecode reads as []: the schema says it is NaN.
            num = struct('type', {{"number"; "null"}});
            p.s = num;
            p.v = struct('type', "array", 'items', num);
            p.n = struct('type', "number");
            p.rec = struct('type', "object", 'properties', struct('a', num));
            schema = struct('type', "object", 'properties', p);
            [a, msg] = prodserver.mcp.jsonrpc.decodeJSONValues(schema, ...
                jsondecode('{"s":null,"v":[],"n":null,"rec":{"a":null}}'), "Output");
            test.verifyEqual(msg, "");
            test.verifyEqual(a.s, NaN, "a nullable number");
            test.verifyEqual(a.v, [], "an empty array is not null");
            test.verifyEqual(a.n, [], "a number that can't be null is left alone");
            test.verifyEqual(a.rec.a, NaN, "a struct field");
            a = prodserver.mcp.jsonrpc.decodeJSONValues(schema, ...
                jsondecode('{"s":2,"v":[1,null]}'), "Output");
            test.verifyEqual(a.s, 2);
            test.verifyEqual(a.v, [1; NaN]);
        end

        function infiniteText(test)
            % "Inf" and "-Inf" are Inf and -Inf where the schema says a
            % number may be (see allowNonFiniteNumbers); a mixed array,
            % which jsondecode gives as a cell, is the numeric array.
            num = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(struct('type', "number"));
            p.s = num;
            p.v = struct('type', "array", 'items', num);
            p.m = p.v;
            p.label = struct('type', "string");
            p.rec = struct('type', "object", 'properties', struct('z', num));
            schema = struct('type', "object", 'properties', p);
            [a, msg] = prodserver.mcp.jsonrpc.decodeJSONValues(schema, jsondecode( ...
                ['{"s":"-Inf","v":[1,"Inf",null],"m":[[1,"Inf"],["-Inf",4]],' ...
                 '"label":"Inf","rec":{"z":"Inf"}}']), "Output");
            test.verifyEqual(msg, "");
            test.verifyEqual(a.s, -Inf);
            test.verifyEqual(a.v, [1; Inf; NaN], "a column, as jsondecode gives a vector");
            test.verifyEqual(a.m, [1 Inf; -Inf 4], "one row for each inner array");
            test.verifyEqual(a.label, 'Inf', "a string is left alone");
            test.verifyEqual(a.rec.z, Inf);
            a = prodserver.mcp.jsonrpc.decodeJSONValues(schema, ...
                jsondecode('{"s":null,"v":["Inf"]}'), "Output");
            test.verifyEqual(a.s, NaN);
            test.verifyEqual(a.v, Inf, "an array of only text");
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

        function structArrayUnderAnObjectSchema(test)
            % The example returned one struct; the tool returns several.
            % Each one's fields follow the properties.
            num = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(struct('type', "number"));
            s = struct('type', "object", 'properties', struct('a', num));
            b = outputs(s, '{"y":[{"a":null},{"a":"Inf"}]}');
            test.verifyEqual([b.y.a], [NaN Inf]);
            b = outputs(s, '{"y":{"a":null}}');
            test.verifyEqual(b.y.a, NaN);
        end

        function stringArrayOutputs(test)
            % An output's array of strings is the string array its schema
            % describes, whatever its length: jsondecode gives a cell, or
            % for one element, a char.
            sa = struct('type', "array", 'items', struct('type', "string"));
            b = outputs(sa, '{"y":["abc"]}');
            test.verifyEqual(b.y, "abc");
            b = outputs(sa, '{"y":["a","b"]}');
            test.verifyEqual(b.y, ["a"; "b"], "a column, as numbers are");
            b = outputs(sa, '{"y":[["a","b"],["c","d"]]}');
            test.verifyEqual(b.y, ["a" "b"; "c" "d"], "a matrix's rows");
            b = outputs(sa, '{"y":[null,"x"]}');
            test.verifyTrue(ismissing(b.y(1)), "null is missing");
            test.verifyEqual(b.y(2), "x");
            b = outputs(sa, '{"y":[]}');
            test.verifyEqual(b.y, strings(0, 1));
            b = outputs(sa, '{"y":["a",1]}');
            test.verifyClass(b.y, 'cell', "not all text: left alone");
            % All null: jsondecode gives NaN, not a cell.
            b = outputs(sa, '{"y":[null]}');
            test.verifyEqual(b.y, string(missing), "one missing string");
            b = outputs(sa, '{"y":[null,null]}');
            test.verifyEqual(b.y, repmat(string(missing), 2, 1), "a column");
            b = outputs(sa, '{"y":[[null,null,null],[null,null,null]]}');
            test.verifyEqual(b.y, repmat(string(missing), 2, 3), "a matrix");
            b = outputs(sa, '{"y":[1,2]}');
            test.verifyEqual(b.y, [1; 2], "numbers: left alone");
            % As the server sends them.
            P = @(v, s) jsonencode(struct('y', ...
                {prodserver.mcp.jsonrpc.plainJSONValue(v, s)}));
            m = repmat(string(missing), 2, 3);
            m(1, 2) = "x";
            m3 = repmat(string(missing), 2, 2, 2);
            m3(1, 1, 1) = "x";
            for v = {string(missing), repmat(string(missing), 1, 2), ...
                    repmat(string(missing), 2, 3), m, m', m3}
                b = outputs(sa, P(v{1}, sa));
                expected = v{1};
                if isvector(expected)
                    expected = expected(:);
                end
                test.verifyEqual(b.y, expected, mat2str(size(v{1})));
            end
            either = struct('anyOf', {{struct('type', "string"), sa}});
            b = outputs(either, P(string(missing), either));
            test.verifyEqual(b.y, string(missing), "a scalar, where an array may be");
            b = outputs(either, P("a", either));
            test.verifyEqual(b.y, 'a', "text, as before");
            % [null] may be a number's NaN: the numbers' alternative claims
            % it first, wherever it is listed.
            num = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(struct('type', "number"));
            nums = struct('type', "array", 'items', num);
            for alts = {{sa, num}, {num, sa}, {sa, nums}}
                s = struct('anyOf', {alts{1}});
                b = outputs(s, P(NaN, s));
                test.verifyEqual(b.y, NaN, "NaN");
            end
            s = struct('anyOf', {{sa, nums}});
            b = outputs(s, '{"y":[null,null]}');
            test.verifyEqual(b.y, [NaN; NaN], "NaNs, where numbers may be");
            s = struct('anyOf', {{sa, num}});
            b = outputs(s, '{"y":[null,null]}');
            test.verifyEqual(b.y, repmat(string(missing), 2, 1), ...
                "strings, where only one number may be");
            % So a missing string beside a number is NaN: plain JSON can't
            % tell them apart.
            s = struct('anyOf', {{num, sa}});
            b = outputs(s, P(string(missing), s));
            test.verifyEqual(b.y, NaN, "a missing string beside a number");
            % Not an argument: a cell parameter's items may be strings.
            a = prodserver.mcp.jsonrpc.decodeJSONValues(jsondecode(jsonencode( ...
                struct('properties', struct('y', sa)))), ...
                jsondecode('{"y":["a","b"]}'), "Argument");
            test.verifyClass(a.y, 'cell');
        end

        function emptyWhereAnArrayMayBe(test)
            % jsondecode gives null and [] alike: where an array may be,
            % [] is the empty array, and plainJSONValue sends NaN as [null].
            num = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(struct('type', "number"));
            either = struct('anyOf', {{num, struct('type', "array", 'items', num)}});
            b = outputs(either, '{"y":[]}');
            test.verifyEqual(b.y, []);
            b = outputs(either, '{"y":[null]}');
            test.verifyEqual(b.y, NaN);
            import prodserver.mcp.jsonrpc.WireShape
            dt = prodserver.mcp.jsonrpc.jsonTimeSchema("datetime", WireShape.Scalar);
            dts = prodserver.mcp.jsonrpc.jsonTimeSchema("datetime", WireShape.Array);
            b = outputs(struct('anyOf', {{dt, dts}}), '{"y":[null]}');
            test.verifyTrue(isscalar(b.y) && isnat(b.y), "NaT");
            b = outputs(struct('anyOf', {{dt, dts}}), '{"y":[]}');
            test.verifyTrue(isdatetime(b.y) && isempty(b.y), "no datetimes");
            % Not in an argument: a client sends NaT as null, and its
            % encoder knows no schema.
            s = jsondecode(jsonencode(struct('properties', struct('y', ...
                struct('anyOf', {{dt, dts}})))));
            sent = jsonencode(struct('y', ...
                {prodserver.mcp.jsonrpc.plainJSONValue(NaT)}));
            a = prodserver.mcp.jsonrpc.decodeJSONValues(s, jsondecode(sent), ...
                "Argument");
            test.verifyTrue(isscalar(a.y) && isnat(a.y), "a NaT argument");
            a = prodserver.mcp.jsonrpc.decodeJSONValues(s, ...
                jsondecode('{"y":[null]}'), "Argument");
            test.verifyTrue(isscalar(a.y) && isnat(a.y), "[null] too");
        end

        function infTextIsAStringFirst(test)
            % Under anyOf [string, number], as the example path writes an
            % output seen with both, "Inf" is the string it may be. Only
            % with no string alternative is it the number Inf.
            num = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(struct('type', "number"));
            f = @(alts, json) prodserver.mcp.jsonrpc.decodeJSONValues( ...
                jsondecode(jsonencode(struct('properties', struct('y', ...
                struct('anyOf', {alts}))))), jsondecode(json), "Output");
            for alts = {{struct('type', "string"), num}, {num, struct('type', "string")}}
                [b, msg] = f(alts{1}, '{"y":"Inf"}');
                test.verifyEqual(msg, "");
                test.verifyEqual(b.y, 'Inf');
                b = f(alts{1}, '{"y":null}');
                test.verifyTrue(isnan(b.y));
            end
            [b, msg] = f({num, struct('type', "boolean")}, '{"y":"-Inf"}');
            test.verifyEqual(msg, "");
            test.verifyEqual(b.y, -Inf);
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

function b = outputs(s, json)
% decodeJSONValues on outputs: JSON, as a client receives it, of an output y
% whose schema is S.
    b = prodserver.mcp.jsonrpc.decodeJSONValues(jsondecode(jsonencode( ...
        struct('properties', struct('y', s)))), jsondecode(json), "Output");
end
