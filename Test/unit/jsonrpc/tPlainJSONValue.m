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

        function complexIsAnError(test)
            % Plain JSON has no form for an imaginary part. The framework's
            % error, not jsonencode's, wherever the value is.
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            id = "prodserver:mcp:IncompatibleArgumentType";
            test.verifyError(@() P(1+2i), id, "scalar");
            test.verifyError(@() P([1 2i]), id, "array");
            test.verifyError(@() P(struct('a', {1, 2i})), id, "in a struct array");
            test.verifyError(@() P({1, 2i}), id, "in a cell");
            test.verifyError(@() P(table([1; 2i])), id, "in a table");
            % Invertible carries it.
            out = prodserver.mcp.jsonrpc.mcpEncode( ...
                prodserver.mcp.WireEncoding.Invertible, 1+2i);
            test.verifyEqual(out{1}, ...
                prodserver.mcp.jsonrpc.mcpWireEncodeValue(1+2i));
        end

        function scalarNaNIsSentAsArray(test)
            % jsondecode reads a member's null as [], but [null] as NaN.
            % In an array, a cell or a table column, null reads back as
            % NaN already, so it is left alone.
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            roundTrip = @(v) jsondecode(jsonencode(struct('m', {P(v)}))).m;
            test.verifyEqual(roundTrip(NaN), NaN, "an argument or output");
            test.verifyEqual(roundTrip(single(NaN)), NaN, "single");
            test.verifyEqual(roundTrip(seconds(NaN)), NaN, "a NaN duration");
            s = roundTrip(struct('a', NaN, 'b', 2));
            test.verifyEqual(s.a, NaN, "a struct field");
            s = roundTrip(struct('a', {1, NaN}));
            test.verifyEqual(s(2).a, NaN, "a struct array element's field");
            test.verifyEqual(P({1, NaN}), {1, NaN}, "a cell element");
            T = table([1; NaN]);
            test.verifyEqual(P(T), T, "a table column");
            test.verifyEqual(P([1 NaN]), [1 NaN], "an array");
            test.verifyEqual(P(3), 3, "a finite scalar");
        end

        function schemaSaysTheForm(test)
            % With its published schema, a value is written in the form the
            % schema describes, which a client that checks it accepts.
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            J = @(v, s) string(jsonencode(struct('m', {P(v, s)})));
            num = struct('type', {{"number"; "null"}});
            arr = struct('type', "array", 'items', num);
            test.verifyEqual(J(NaN, num), "{""m"":null}", "a scalar NaN");
            test.verifyEqual(J(3, num), "{""m"":3}");
            % A schema that allows no null, as a %#schema may replace it:
            % [null], as with no schema, which arrives as NaN. A client
            % would read null as [].
            plain = struct('type', "number");
            test.verifyEqual(J(NaN, plain), "{""m"":[null]}", "a plain number");
            test.verifyEqual(J(NaN, struct('type', "integer")), "{""m"":[null]}");
            test.verifyEqual(J(3, plain), "{""m"":3}");
            os = struct('properties', struct('m', plain));
            out = prodserver.mcp.jsonrpc.decodeJSONValues(os, ...
                jsondecode(J(NaN, plain)), "Output");
            test.verifyEqual(out.m, NaN, "it arrives as NaN");
            fs = struct('type', "object", 'properties', struct('a', plain));
            test.verifyEqual(J(struct('a', NaN), fs), "{""m"":{""a"":[null]}}", ...
                "a struct field");
            test.verifyEqual(J(NaN, arr), "{""m"":[null]}", "an array of one NaN");
            test.verifyEqual(J(5, arr), "{""m"":[5]}", "an array of one");
            test.verifyEqual(J([1 NaN], arr), "{""m"":[1,null]}");
            test.verifyEqual(J(true, struct('type', "array", 'items', ...
                struct('type', "boolean"))), "{""m"":[true]}");
            test.verifyEqual(J("a", struct('type', "array", 'items', ...
                struct('type', "string"))), "{""m"":[""a""]}");
            test.verifyEqual(J(seconds(NaN), prodserver.mcp.jsonrpc.jsonTimeSchema( ...
                "duration", prodserver.mcp.jsonrpc.WireShape.Scalar)), ...
                "{""m"":null}", "a NaN duration");
            % A struct's fields follow its properties; an array of one
            % struct is an array.
            rec = struct('type', "object", 'properties', ...
                struct('a', num, 'b', arr));
            test.verifyEqual(J(struct('a', NaN, 'b', 4), rec), ...
                "{""m"":{""a"":null,""b"":[4]}}");
            test.verifyEqual(J(struct('a', 1, 'b', [1 2]), ...
                struct('type', "array", 'items', rec)), ...
                "{""m"":[{""a"":1,""b"":[1,2]}]}");
            % A cell's elements follow its items.
            test.verifyEqual(J({NaN, 2}, arr), "{""m"":[null,2]}");
            % Alternatives, or no type, say neither: as without a schema.
            either = struct('anyOf', {{num, arr}});
            test.verifyEqual(J(NaN, either), "{""m"":[null]}");
            test.verifyEqual(J(NaN, struct()), "{""m"":[null]}");
            test.verifyEqual(J(NaN, []), "{""m"":[null]}");
        end

        function emptyWhereTheSchemaIsOneValueIsAnError(test)
            % jsondecode reads [] as it reads null, so the client would get
            % NaN. Under a schema of one value, [] is no form it allows.
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            J = @(v, s) string(jsonencode(struct('m', {P(v, s)})));
            num = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(struct('type', "number"));
            id = "prodserver:mcp:EmptyScalarOutput";
            test.verifyError(@() P([], num), id, "a number");
            test.verifyError(@() P(zeros(1, 0), struct('type', "integer")), id);
            test.verifyError(@() P(string.empty, struct('type', "string")), id);
            test.verifyError(@() P(struct('a', []), struct('type', "object", ...
                'properties', struct('a', num))), id, "a struct field");
            % The value's message says what to declare; a field's names it,
            % and what to do instead.
            message = @(f) errorMessage(test, f, id);
            msg = string(message(@() P([], num)));
            test.verifySubstring(msg, "The value is empty");
            test.verifySubstring(msg, "arguments (Output)");
            obj = @(p) struct('type', "object", 'properties', p);
            msg = string(message(@() P(struct('a', []), obj(struct('a', num)))));
            test.verifySubstring(msg, "Its field 'a' is empty");
            test.verifySubstring(msg, "add an example call that returns it empty");
            test.verifySubstring(msg, "%#schema");
            test.verifyFalse(contains(msg, "arguments (Output)"), msg);
            inner = obj(struct('b', num));
            msg = string(message(@() P(struct('a', struct('b', [])), ...
                obj(struct('a', inner)))));
            test.verifySubstring(msg, "Its field 'a.b' is empty", "nested");
            msg = string(message(@() P(struct('a', [struct('b', 1), struct('b', [])]), ...
                obj(struct('a', inner)))));
            test.verifySubstring(msg, "Its field 'a(2).b' is empty", "nested array");
            msg = string(message(@() P(struct('a', {1, []}), ...
                struct('type', "array", 'items', obj(struct('a', num))))));
            test.verifySubstring(msg, "Its field '(2).a' is empty", "a struct array");
            msg = string(message(@() P({1, struct('a', [])}, struct('type', "array", ...
                'items', obj(struct('a', num))))));
            test.verifySubstring(msg, "Its field '{2}.a' is empty", "in a cell");
            % Text, an array schema, or no schema: as before.
            test.verifyEqual(J('', struct('type', "string")), "{""m"":""""}");
            test.verifyEqual(J([], struct('type', "array", 'items', num)), "{""m"":[]}");
            test.verifyEqual(J([], []), "{""m"":[]}");
            % Alternatives each of one value are one value too. One with no
            % type may be an array; so may one that is.
            text = struct('type', "string");
            test.verifyError(@() P([], struct('anyOf', {{num}})), id);
            test.verifyError(@() P([], struct('anyOf', {{num, text}})), id, "anyOf [number, string]");
            test.verifyError(@() P(string.empty, struct('oneOf', {{text, num}})), id);
            msg = string(message(@() P(struct('a', []), obj(struct('a', ...
                struct('anyOf', {{num, text}}))))));
            test.verifySubstring(msg, "Its field 'a' is empty", "a field");
            test.verifyEqual(J([], struct('anyOf', {{num, struct('enum', [1; 2])}})), ...
                "{""m"":[]}", "no type");
            test.verifyEqual(J([], struct('anyOf', {{num, struct('type', "array", ...
                'items', num)}})), "{""m"":[]}", "an array");
            test.verifyEqual(J('', struct('anyOf', {{num, text}})), "{""m"":""""}", ...
                "text, as before");
            % Where an alternative allows null, and a client reads it back
            % as empty -- null, beside text -- it is null: it was an error,
            % which said it would be NaN.
            nul = struct('type', "null");
            test.verifyEqual(J([], struct('anyOf', {{text, nul}})), "{""m"":null}", "nullable");
            test.verifyEqual(J(string.empty, struct('oneOf', {{nul, text}})), "{""m"":null}");
            test.verifyEqual(J([], struct('anyOf', {{text, struct('type', ["string" "null"])}})), ...
                "{""m"":null}", "a type list with null");
            test.verifyEqual(string(jsonencode(P(struct('a', []), obj(struct('a', ...
                struct('anyOf', {{text, nul}})))))), "{""a"":null}", "a nullable field");
            test.verifyError(@() P([], struct('anyOf', {{num, nul}})), id, ...
                "a number's null is NaN");
            % Without null, [] is no value they allow, whatever a client
            % reads it as.
            plain = @(t) struct('type', t);
            for alts = {{text, plain("number")}, {text, plain("boolean")}, ...
                    {plain("object"), text}, {plain("integer"), text}}
                test.verifyError(@() P([], struct('anyOf', {alts{1}})), id, ...
                    jsonencode(alts{1}));
            end
            test.verifyError(@() P(false(1, 0), struct('anyOf', ...
                {{text, plain("boolean")}})), id, "an empty boolean");
            msg = string(message(@() P(struct('f', []), obj(struct('f', ...
                struct('anyOf', {{text, plain("boolean")}}))))));
            test.verifySubstring(msg, "Its field 'f' is empty", "a field");
        end

        function singleValueFollowsAnArrayOfItsType(test)
            % Example calls returning ["a" "b"] and 5 give anyOf [array of
            % string, number]. A single string was sent bare, under the
            % number, whose type lists string for "Inf": "z" matched
            % neither, and "Inf" came back as the number Inf.
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            num = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(struct('type', "number"));
            texts = struct('type', "array", 'items', struct('type', "string"));
            nums = struct('type', "array", 'items', num);
            text = struct('type', "string");
            cases = {
                % schema                              value    sent         read back
                struct('anyOf', {{texts, num}}),      "z",     '["z"]',     "z"
                struct('anyOf', {{texts, num}}),      "Inf",   '["Inf"]',   "Inf"
                % A char row, as a string: 'Inf' came back as the number.
                struct('anyOf', {{texts, num}}),      'z',     '["z"]',     "z"
                struct('anyOf', {{texts, num}}),      'Inf',   '["Inf"]',   "Inf"
                struct('anyOf', {{num, texts}}),      '',      '[""]',      ""
                struct('anyOf', {{num, texts}}),      "z",     '["z"]',     "z"
                struct('anyOf', {{texts, num}}),      5,       '5',         5
                struct('anyOf', {{texts, num}}),      Inf,     '"Inf"',     Inf
                struct('anyOf', {{texts, num}}),      ["a" "b"], '["a","b"]', ["a"; "b"]
                struct('anyOf', {{nums, texts}}),     5,       '[5]',       5
                struct('anyOf', {{nums, texts}}),     "z",     '["z"]',     "z"
                struct('anyOf', {{text, num}}),       "z",     '"z"',       'z'
                struct('anyOf', {{num, text}}),       "z",     '"z"',       'z'
                % An alternative with no type may be the value's as it is.
                struct('anyOf', {{nums, struct('const', 0)}}), 0, '0',     0
                };
            for k = 1:size(cases, 1)
                [s, v, sent, back] = cases{k,:};
                j = jsonencode(struct('m', {P(v, s)}));
                context = jsonencode(s) + " with " + jsonencode(v);
                test.verifyEqual(j, ['{"m":' sent '}'], context);
                os = struct('properties', struct('m', s));
                b = prodserver.mcp.jsonrpc.decodeJSONValues(os, jsondecode(j), "Output");
                test.verifyEqual(b.m, back, context);
            end
        end

        function infiniteTextMustReadBackAsText(test)
            % Under anyOf [array of nonfinite number, array of string], as
            % example calls returning [1 2] and ["a" "b"] give, ["Inf"] is
            % both the number Inf and the text, and a client reads it as
            % the number: the text came back as Inf.
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            num = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(struct('type', "number"));
            nums = struct('type', "array", 'items', num);
            texts = struct('type', "array", 'items', struct('type', "string"));
            s = struct('anyOf', {{nums, texts}});
            id = "prodserver:mcp:IncompatibleArgumentType";
            for v = {'Inf', "-Inf", ["Inf" "-Inf"]}
                test.verifyError(@() P(v{1}, s), id, jsonencode(v{1}));
            end
            msg = string(errorMessage(test, @() P('Inf', s), id));
            test.verifySubstring(msg, "would read it back as a number");
            % The number is read back as sent; other text too.
            os = struct('properties', struct('m', s));
            cases = {Inf, Inf; [1 -Inf], [1; -Inf]; 'z', "z"; ["a" "b"], ["a"; "b"]; ...
                ["a" "Inf"], ["a"; "Inf"]};
            for k = 1:size(cases, 1)
                j = jsonencode(struct('m', {P(cases{k,1}, s)}));
                b = prodserver.mcp.jsonrpc.decodeJSONValues(os, jsondecode(j), "Output");
                test.verifyEqual(b.m, cases{k,2}, j);
            end
            % Text with a missing string, which reads back as sent: it was
            % refused, as missing is never == missing.
            m = struct('anyOf', {{texts, nums}});
            om = struct('properties', struct('m', m));
            for v = {["Inf" missing], ["-Inf" missing "b"]}
                j = jsonencode(struct('m', {P(v{1}, m)}));
                b = prodserver.mcp.jsonrpc.decodeJSONValues(om, jsondecode(j), "Output");
                sent = v{1}(:);
                test.verifyClass(b.m, "string", j);
                test.verifyEqual(ismissing(b.m), ismissing(sent), j);
                test.verifyEqual(b.m(~ismissing(b.m)), sent(~ismissing(sent)), j);
            end
            % Where a client reads the text back as text, it is sent.
            test.verifyEqual(jsonencode(struct('m', {P('Inf', ...
                struct('anyOf', {{texts, num}}))})), '{"m":["Inf"]}');
            test.verifyEqual(jsonencode(struct('m', {P('Inf', ...
                struct('anyOf', {{struct('type', "string"), num}}))})), '{"m":"Inf"}');
        end

        function structFieldsFollowTheAlternativeThatFits(test)
            % Example calls returning struct('a',{1,2}) and struct('a',[1 2
            % 3]) give anyOf [array of {a: number}, {a: array of number}].
            % A struct's fields were written by the schemas of both, in
            % forms neither allows: {"a":7}, not {"a":[7]}.
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            num = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(struct('type', "number"));
            nums = struct('type', "array", 'items', num);
            obj = @(p) struct('type', "object", 'properties', p);
            s = struct('anyOf', {{struct('type', "array", 'items', obj(struct('a', num))), ...
                obj(struct('a', nums))}});
            cases = {
                struct('a', 7),          '{"m":{"a":[7]}}'
                struct('a', Inf),        '{"m":{"a":["Inf"]}}'
                struct('a', NaN),        '{"m":{"a":[null]}}'
                struct('a', [1; 2; 3]),  '{"m":{"a":[1,2,3]}}'
                struct('a', {1, NaN}),   '{"m":[{"a":1},{"a":null}]}'
                struct('a', {1, Inf}),   '{"m":[{"a":1},{"a":"Inf"}]}'
                };
            os = struct('properties', struct('m', s));
            for k = 1:size(cases, 1)
                v = cases{k,1};
                j = jsonencode(struct('m', {P(v, s)}));
                test.verifyEqual(j, cases{k,2}, jsonencode(v));
                b = prodserver.mcp.jsonrpc.decodeJSONValues(os, jsondecode(j), "Output");
                expected = v;
                if ~isscalar(v)
                    expected = v(:);
                end
                if isscalar(v) && isscalar(v.a)
                    % One element of an array of numbers: as jsondecode
                    % reads [7], or [null].
                    expected.a = v.a;
                end
                test.verifyEqual(b.m, expected, j);
            end
        end

        function alternativesFollowTheValuesShape(test)
            % As the example path writes an output seen in both shapes, or
            % with two classes: the value follows the alternative its shape
            % fits, preferring its own JSON type.
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            J = @(v, s) string(jsonencode(struct('m', {P(v, s)})));
            num = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(struct('type', "number"));
            either = struct('anyOf', {{num, struct('type', "array", 'items', num)}});
            test.verifyEqual(J(Inf, either), "{""m"":""Inf""}");
            test.verifyEqual(J([1 Inf], either), "{""m"":[1,""Inf""]}");
            test.verifyEqual(J(5, either), "{""m"":5}");
            test.verifyEqual(J([], either), "{""m"":[]}", "empty: the array");
            test.verifyEqual(J(NaN, either), "{""m"":[null]}", ...
                "NaN: [null], as null would read back as []");
            textOrNumber = struct('anyOf', {{struct('type', "string"), num}});
            test.verifyEqual(J('x', textOrNumber), "{""m"":""x""}");
            test.verifyEqual(J(5, textOrNumber), "{""m"":5}");
            test.verifyEqual(J(NaN, textOrNumber), "{""m"":null}");
            test.verifyEqual(J([1 -Inf], ...
                struct('anyOf', {{struct('type', "string"), ...
                struct('type', "array", 'items', num)}})), "{""m"":[1,""-Inf""]}", ...
                "[1,""-Inf""] isn't text");
        end

        function infiniteTextMustReadBackAsANumber(test)
            % Under anyOf [string, number], as the example path writes an
            % output seen with both classes, a client reads "Inf" as the
            % string it may be (decodeJSONValues). So the value is an
            % error, not text that arrives as text.
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            num = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(struct('type', "number"));
            text = struct('type', "string");
            id = "prodserver:mcp:IncompatibleArgumentType";
            for alts = {{text, num}, {num, text}}
                s = struct('anyOf', {alts{1}});
                test.verifyError(@() P(-Inf, s), id);
                test.verifyError(@() P(struct('a', Inf), struct('type', ...
                    "object", 'properties', struct('a', s))), id, "a struct field");
            end
            % An array of Inf alone is text the strings may be.
            strs = struct('type', "array", 'items', text);
            nums = struct('type', "array", 'items', num);
            test.verifyError(@() P([Inf -Inf], struct('anyOf', {{strs, nums}})), id);
            % Elsewhere, Inf reads back as Inf.
            readBack = @(v, s) prodserver.mcp.jsonrpc.decodeJSONValues( ...
                struct('properties', struct('m', s)), ...
                jsondecode(jsonencode(struct('m', {P(v, s)}))), "Output").m;
            either = struct('anyOf', {{num, nums}});
            test.verifyEqual(readBack(Inf, either), Inf);
            test.verifyEqual(readBack([1 -Inf], either), [1; -Inf]);
            test.verifyEqual(readBack([1 Inf; -Inf 2], either), [1 Inf; -Inf 2]);
            test.verifyEqual(readBack([1 -Inf], struct('anyOf', {{strs, nums}})), ...
                [1; -Inf], "not all text");
        end

        function arrayAlternativeFollowsTheItemsType(test)
            % Of the alternatives that are arrays, the one whose items are
            % of the elements' type: the first, a string array, can't carry
            % Inf.
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            J = @(v, s) string(jsonencode(struct('m', {P(v, s)})));
            num = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(struct('type', "number"));
            strs = struct('type', "array", 'items', struct('type', "string"));
            nums = struct('type', "array", 'items', num);
            s = struct('anyOf', {{strs, nums}});
            test.verifyEqual(J([1 Inf], s), "{""m"":[1,""Inf""]}");
            test.verifyEqual(J(["a" "b"], s), "{""m"":[""a"",""b""]}");
            test.verifyEqual(J(NaN, s), "{""m"":[null]}", "a NaN in the numbers");
            % A struct array's fields follow the struct items' properties.
            objs = struct('type', "array", 'items', struct('type', "object", ...
                'properties', struct('a', num)));
            test.verifyEqual(J(struct('a', {1, Inf}), struct('anyOf', {{nums, objs}})), ...
                "{""m"":[{""a"":1},{""a"":""Inf""}]}");
            % With no items of the type, the first array, as before.
            test.verifyError(@() P([1 Inf], struct('anyOf', {{strs, ...
                struct('type', "array", 'items', struct('type', "boolean"))}})), ...
                "prodserver:mcp:IncompatibleArgumentType");
        end

        function alternativesWithoutAType(test)
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            J = @(v, s) string(jsonencode(struct('m', {P(v, s)})));
            % An alternative with no type, as a %#schema may give: it has no
            % shape to fit, and was an error.
            textOrEnum = jsondecode('{"anyOf": [{"type": "string"}, {"enum": [1, 2]}]}');
            test.verifyEqual(J("a", textOrEnum), "{""m"":""a""}");
            test.verifyEqual(J(1, textOrEnum), "{""m"":1}");
            listOrNone = jsondecode(['{"anyOf": [{"type": "array", "items": ' ...
                '{"type": "number"}}, {"enum": ["none"]}, {"const": 0}, {}]}']);
            test.verifyEqual(J([1 2 3], listOrNone), "{""m"":[1,2,3]}");
            test.verifyEqual(J(5, listOrNone), "{""m"":5}");
            test.verifyEqual(J("none", listOrNone), "{""m"":""none""}");
            os = struct('properties', struct('m', listOrNone));
            out = prodserver.mcp.jsonrpc.decodeJSONValues(os, ...
                jsondecode(J([1 2 3], listOrNone)), "Output");
            test.verifyEqual(out.m, [1; 2; 3], "the client reads it back");
        end

        function infiniteIsTextWhereTheSchemaAllowsIt(test)
            % An output's schema allows "Inf" and "-Inf" (see
            % allowNonFiniteNumbers): jsonencode would write null, which
            % reads back as NaN.
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            J = @(v, s) string(jsonencode(struct('m', {P(v, s)})));
            num = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(struct('type', "number"));
            arr = struct('type', "array", 'items', num);
            test.verifyEqual(J(Inf, num), "{""m"":""Inf""}");
            test.verifyEqual(J(-Inf, num), "{""m"":""-Inf""}");
            test.verifyEqual(J(single(Inf), num), "{""m"":""Inf""}", "single");
            test.verifyEqual(J(NaN, num), "{""m"":null}");
            test.verifyEqual(J([1 Inf NaN -Inf], arr), ...
                "{""m"":[1,""Inf"",null,""-Inf""]}", "a vector");
            test.verifyEqual(J(Inf, arr), "{""m"":[""Inf""]}", "an array of one");
            test.verifyEqual(J([1 Inf; -Inf 4], arr), ...
                "{""m"":[[1,""Inf""],[""-Inf"",4]]}", "a matrix's rows");
            test.verifyEqual(J([1 2; 3 4], arr), "{""m"":[[1,2],[3,4]]}", ...
                "a finite matrix, as jsonencode writes it");
            rec = struct('type', "object", 'properties', struct('z', num));
            test.verifyEqual(J(struct('z', -Inf), rec), "{""m"":{""z"":""-Inf""}}");
            % A schema that doesn't allow the text: an error, as before.
            id = "prodserver:mcp:IncompatibleArgumentType";
            test.verifyError(@() P(Inf, struct('type', {{"number"; "null"}})), id);
            test.verifyError(@() P(seconds(Inf), prodserver.mcp.jsonrpc.jsonTimeSchema( ...
                "duration", prodserver.mcp.jsonrpc.WireShape.Scalar)), id, ...
                "an infinite duration");
        end

        function infiniteIsAnError(test)
            % jsonencode writes Inf and -Inf as null, as it does NaN, so
            % they would arrive as NaN. Wherever the value is.
            P = @prodserver.mcp.jsonrpc.plainJSONValue;
            id = "prodserver:mcp:IncompatibleArgumentType";
            test.verifyError(@() P(Inf), id, "scalar");
            test.verifyError(@() P([NaN Inf -Inf]), id, "array");
            test.verifyError(@() P(single(-Inf)), id, "single");
            test.verifyError(@() P(struct('a', {1, Inf})), id, "in a struct array");
            test.verifyError(@() P({1, -Inf}), id, "in a cell");
            test.verifyError(@() P(table([1; Inf])), id, "in a table");
            test.verifyError(@() P(seconds(Inf)), id, "an infinite duration");
            % NaN survives in an array, and an integer can't be infinite.
            test.verifyEqual(P([1 NaN]), [1 NaN]);
            test.verifyEqual(P(intmax("int32")), intmax("int32"));
            % Invertible carries it.
            out = prodserver.mcp.jsonrpc.mcpEncode( ...
                prodserver.mcp.WireEncoding.Invertible, [1 Inf]);
            test.verifyEqual(out{1}, ...
                prodserver.mcp.jsonrpc.mcpWireEncodeValue([1 Inf]));
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

function msg = errorMessage(test, f, id)
% The message of the error F raises, verifying its identifier is ID.
    msg = "";
    try
        f();
        test.verifyFail("expected the error " + id);
    catch err
        test.verifyEqual(string(err.identifier), id);
        msg = string(err.message);
    end
end
