classdef tSchemaConstraints < matlab.unittest.TestCase
%tSchemaConstraints Verify that tools/call arguments are checked against
%the constraints a schema puts on numbers, strings, arrays and objects.
%   The validator checked each value's type only, so a constraint only a
%   %#schema states -- a minimum, a pattern -- was published to the client
%   but never checked, and a call that broke it reached the tool.

% Copyright 2026 The MathWorks, Inc.

    methods(TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods(Test)

        function numbers(test)
            cases = {
                '{"type": "number", "minimum": 2}',              2,    ""
                '{"type": "number", "minimum": 2}',              1,    "value 1 is less than the minimum, 2"
                '{"type": "number", "maximum": 10}',             10,   ""
                '{"type": "number", "maximum": 10}',             11,   "value 11 is greater than the maximum, 10"
                '{"type": "number", "exclusiveMinimum": 0}',     0.5,  ""
                '{"type": "number", "exclusiveMinimum": 0}',     0,    "value 0 must be greater than 0"
                '{"type": "number", "exclusiveMaximum": 10}',    10,   "value 10 must be less than 10"
                '{"type": "number", "minimum": 0, "exclusiveMinimum": true}', 0, "value 0 must be greater than 0"
                '{"type": "number", "maximum": 1, "exclusiveMaximum": false}', 1, ""
                '{"type": "number", "multipleOf": 0.1}',         0.3,  ""
                '{"type": "number", "multipleOf": 0.1}',         0.25, "value 0.25 is not a multiple of 0.1"
                '{"type": "integer", "minimum": 1}',             0,    "value 0 is less than the minimum, 1"
                };
            verifyCases(test, cases);
        end

        function strings(test)
            emoji = char([0xD83D 0xDE00]);
            cases = {
                '{"type": "string", "minLength": 2}',            'ab',      ""
                '{"type": "string", "minLength": 2}',            'a',       "string has 1 character, minimum is 2"
                '{"type": "string", "maxLength": 5}',            'abcdef',  "string has 6 characters, maximum is 5"
                '{"type": "string", "maxLength": 1}',            emoji,     ""
                '{"type": "string", "pattern": "^[A-Z]{3}-\\d{2}$"}', 'ABC-12', ""
                '{"type": "string", "pattern": "^[A-Z]{3}-\\d{2}$"}', 'abc-12', 'string "abc-12" does not match the pattern "^[A-Z]{3}-\\d{2}$"'
                '{"type": "string", "pattern": "b"}',            'abc',     ""
                '{"type": "string", "pattern": "^a.b$"}',        ['a' newline 'b'], 'does not match the pattern'
                '{"type": "string", "pattern": "^(a)\\1$"}',     'aa',      ""
                };
            verifyCases(test, cases);
        end

        function patternMATLABCantCheckIsSkipped(test)
            % Matched by regexp, \p{L} would reject every call.
            verifyCases(test, {'{"type": "string", "pattern": "^\\p{L}+$"}', 'abc', ""});
        end

        function patternsMatchAsECMAScript(test)
            % regexp read \b, \x41, \d and . otherwise, and matched
            % nothing in '', and no a* in 'b'. (See tEcmaPattern.)
            cases = {
                '{"type": "string", "pattern": "\\bcat\\b"}', 'a cat.', ""
                '{"type": "string", "pattern": "^\\x41B$"}',  'AB',     ""
                '{"type": "string", "pattern": "^\\u00e9$"}', char(0xE9), ""
                '{"type": "string", "pattern": "^\\d+$"}',    char([0x661 0x662]), "does not match"
                '{"type": "string", "pattern": "^a.c$"}',     ['a' char(13) 'c'], "does not match"
                '{"type": "string", "pattern": "^[a-z]*$"}',  '',       ""
                '{"type": "string", "pattern": "^$"}',        '',       ""
                '{"type": "string", "pattern": "a*"}',        'b',      ""
                '{"type": "string", "pattern": "x"}',         '',       "does not match"
                };
            verifyCases(test, cases);
        end

        function noTypeChecksByValue(test)
            cases = {
                '{"minimum": 0}',               -1,    "value -1 is less than the minimum, 0"
                '{"minimum": 0}',               'abc', ""
                '{"maxLength": 2}',             'abc', "string has 3 characters, maximum is 2"
                '{"maxLength": 2}',             123,   ""
                };
            verifyCases(test, cases);
        end

        function enumMembersMeetOtherKeywords(test)
            cases = {
                '{"type": "number", "enum": [1, 5], "minimum": 3}', 5, ""
                '{"type": "number", "enum": [1, 5], "minimum": 3}', 1, "value 1 is less than the minimum, 3"
                '{"type": "string", "enum": ["a", "bb"], "minLength": 2}', 'a', "string has 1 character, minimum is 2"
                };
            verifyCases(test, cases);
        end

        function arrays(test)
            cases = {
                '{"type": "array", "items": {"type": "number", "minimum": 0}}', [1; -1], "at index 2: value -1 is less than the minimum, 0"
                '{"type": "array", "minimum": 100}',      [1; 2],                 ""
                '{"type": "array", "uniqueItems": true}', [1; 2; 3],              ""
                '{"type": "array", "uniqueItems": true}', [1; 2; 1],              "items 1 and 3 are equal, but must be unique"
                '{"type": "array", "uniqueItems": true}', {'a'; 'b'; 'b'},        "items 2 and 3 are equal, but must be unique"
                '{"type": "array", "uniqueItems": true}', jsondecode('[[1,2],[1,2]]'), "items 1 and 2 are equal, but must be unique"
                '{"type": "array", "uniqueItems": true}', jsondecode('[{"a":1},{"a":2}]'), ""
                '{"type": "array", "uniqueItems": false}', [1; 1],                ""
                % jsondecode gives [1,null] as [1; NaN]: null is no number.
                '{"type": "array", "items": {"type": ["number", "null"], "minimum": 0}}', jsondecode('[1,null]'), ""
                '{"type": "array", "items": {"type": ["number", "null"], "minimum": 0}}', jsondecode('[-1,null]'), "at index 1: value -1 is less than the minimum, 0"
                };
            verifyCases(test, cases);
        end

        function valuesCompareAsJSON(test)
            % isequal compared values as MATLAB does: text equal to its
            % character codes, a boolean to 0 or 1, and null (NaN) to
            % nothing, not even null.
            cases = {
                '{"enum": ["A"]}',          65,     "value 65 is not one of ""A"""
                '{"enum": ["A"]}',          'A',    ""
                '{"enum": ["A"]}',          "A",    ""
                '{"enum": [1]}',            true,   "value true is not one of 1"
                '{"enum": [true]}',         1,      "value 1 is not one of true"
                '{"enum": [1, 2]}',         int32(2), ""
                '{"enum": [null, 1]}',      [],     ""
                '{"enum": [[1, null]]}',    [1; NaN], ""
                '{"enum": [{"a": [1, null]}]}', struct('a', [1; NaN]), ""
                '{"const": "A"}',           65,     "expected ""A"", got ""65"""
                '{"const": 1}',             true,   "expected ""1"", got ""true"""
                '{"const": [1, null]}',     [1; NaN], ""
                '{"const": {"a": "x", "b": 2}}', struct('b', 2, 'a', 'x'), ""
                '{"const": {"a": "x"}}',    struct('a', 'x', 'b', 2), "expected"
                % A MATLAB caller's own classes compare as isequal does.
                '{"enum": ["a", "b"]}',     categorical("a"), ""
                '{"enum": ["a", "b"]}',     categorical("c"), "is not one of"
                '{"const": "a"}',           categorical("a"), ""
                };
            verifyCases(test, cases);
        end

        function uniqueItemsCompareAsJSON(test)
            u = '{"type": "array", "uniqueItems": true}';
            cases = {
                u, {1; true},             ""
                u, {'A'; 65},             ""
                u, {'a'; "a"},            "items 1 and 2 are equal"
                u, [1; NaN; NaN],         "items 2 and 3 are equal"
                u, {1; []; []},           "items 2 and 3 are equal"
                u, [1; 2; 2; 1],          "items 1 and 4 are equal"
                u, [true; false],         ""
                u, [true; false; true],   "items 1 and 3 are equal"
                u, {'a'; 'b'; 'c'; 'b'},  "items 2 and 4 are equal"
                u, {'a'; ''; ''},         "items 2 and 3 are equal"
                u, int8([1; 2; 1]),       "items 1 and 3 are equal"
                u, zeros(0, 1),           ""
                u, jsondecode('[[1,null],[1,null]]'), "items 1 and 2 are equal"
                u, jsondecode('[{"a":null},{"a":null}]'), "items 1 and 2 are equal"
                };
            verifyCases(test, cases);
        end

        function uniqueItemsScales(test)
            % Each pair was compared: 1e5 numbers took minutes.
            v = (1:1e5)';
            t = tic;
            verifyCases(test, {'{"type": "array", "uniqueItems": true}', v, ""});
            verifyCases(test, {'{"type": "array", "uniqueItems": true}', [v; 7], ...
                "items 7 and 100001 are equal"});
            verifyCases(test, {'{"type": "array", "uniqueItems": true}', ...
                cellstr(string(v)), ""});
            test.verifyLessThan(toc(t), 10);
        end

        function arraysCheckedAtOnceAgreeWithEachItem(test)
            % An array of numbers, booleans or strings is checked all at
            % once where its items' schema allows: it must be valid just
            % when each item is.
            schemas = {'{}', '{"description": "x"}', '{"type": "number"}', ...
                '{"type": "integer"}', '{"type": ["integer", "null"]}', ...
                '{"type": "null"}', '{"type": ["number", "null"], "minimum": 0}', ...
                '{"minimum": 0, "maximum": 10}', '{"type": "number", "exclusiveMinimum": 0}', ...
                '{"type": "number", "minimum": 0, "exclusiveMinimum": true}', ...
                '{"type": "number", "maximum": 1, "exclusiveMaximum": true}', ...
                '{"exclusiveMaximum": 3}', '{"type": "number", "multipleOf": 0.1}', ...
                '{"type": "integer", "multipleOf": 3}', ...
                '{"anyOf": [{"type": "number"}, {"enum": ["NaN", "Inf", "-Inf"]}]}', ...
                '{"anyOf": [{"type": "string"}, {"type": "integer", "minimum": 1}]}', ...
                '{"allOf": [{"minimum": 0}, {"maximum": 5}]}', ...
                '{"anyOf": [{"type": "number"}], "maximum": 2}', ...
                '{"type": "boolean"}', '{"type": "string"}', ...
                '{"type": "string", "minLength": 2, "maxLength": 3}', ...
                '{"type": "string", "pattern": "^[a-c]*$"}', '{"pattern": "\\d"}', ...
                '{"maxLength": 1}', '{"type": "string", "format": "date-time"}', ...
                '{"type": "number", "enum": [1, 2]}', '{"type": ["string", "null"]}', ...
                '{"type": ["number", "string"], "minimum": 2}', ...
                '{"type": "string", "pattern": "^\\p{L}$"}', ...
                '{"enum": ["NaN", "Inf", "-Inf"]}', '{"enum": [1, 2, "a", true]}', ...
                '{"enum": [-0, 3]}', '{"enum": [null, "a"]}', '{"enum": [[1, 2], "ab"]}', ...
                '{"type": "string", "enum": ["ab", "abc", "x"], "minLength": 2}', ...
                '{"anyOf": [{"type": "number", "minimum": 0}, {"enum": ["Inf"]}]}', ...
                '{"anyOf": [{"type": "boolean"}, {"type": "string", "maxLength": 1}]}', ...
                '{"allOf": [{"anyOf": [{"type": "number"}, {"type": "string"}]}, {"maxLength": 2}]}'};
            values = {[1; 2; 3], [0; -1], [1.5; 2], [NaN; 1], [Inf; -Inf], [], ...
                int8([1; 2]), int8(5), zeros(2, 2), [0.3; 0.6], [3; 6; 9], ...
                [true; false], {'ab'; 'abc'}, {'a'; ''}, {''}, ["ab" "abcd"], ...
                ["a" missing], {'1'; 'x'}, {char([0xD83D 0xDE00]); 'ab'}, ...
                {'2026-01-01T00:00:00Z'}, {1; 'a'}, {'ab'; 'cab'}, ...
                {1; 'Inf'; -2; '-Inf'; 'NaN'}, {1; 'inf'}, {1; true; 'a'}, {2; false}, ...
                {0; 3}, {-1; 'Inf'}, {true; 'a'; 'bb'}, {1; []}, {1; [1 2]}, ...
                {'ab'; struct('a', 1)}, {NaN; 'a'}, {single(1); 'a'}, {1; "a"}, {}};
            f = @(schema, v) prodserver.mcp.validation.validateArgumentsWithSchema( ...
                struct('properties', struct('x', schema)), "x", {v});
            for i = 1:numel(schemas)
                items = jsondecode(schemas{i});
                array = struct('type', "array", 'items', items);
                for j = 1:numel(values)
                    v = values{j};
                    each = true;
                    for k = 1:numel(v)
                        if iscell(v), e = v{k}; else, e = v(k); end
                        each = each && strlength(f(items, e)) == 0;
                    end
                    test.verifyEqual(strlength(f(array, v)) == 0, each, ...
                        schemas{i} + " with " + jsonencode(v));
                end
            end
        end

        function arraysCheckedAtOnceScale(test)
            % Each item was checked on its own: 1e5 numbers under the
            % wrapper's items took seconds.
            n = 1e5;
            cases = {
                '{"anyOf": [{"type": "number"}, {"enum": ["NaN", "Inf", "-Inf"]}]}', rand(n, 1)
                '{"type": "integer", "minimum": 0}', (1:n)'
                '{"type": "boolean"}', rand(n, 1) > 0.5
                % An invertible array with Inf in it arrives as a cell.
                '{"anyOf": [{"type": "number"}, {"enum": ["NaN", "Inf", "-Inf"]}]}', ...
                    repmat({1; 'Inf'; 2.5; '-Inf'}, n/4, 1)
                '{"type": "string", "pattern": "^[0-9]+$", "maxLength": 6}', cellstr(string(1:n))'
                };
            for k = 1:size(cases, 1)
                s = struct('type', "array", 'items', jsondecode(cases{k,1}));
                t = tic;
                d = prodserver.mcp.validation.validateArgumentsWithSchema( ...
                    struct('properties', struct('x', s)), "x", cases(k,2));
                test.verifyEqual(d, "", cases{k,1});
                test.verifyLessThan(toc(t), 2, cases{k,1});
            end
        end

        function objects(test)
            cases = {
                '{"type": "object", "minProperties": 2}', struct('a', 1, 'b', 2), ""
                '{"type": "object", "minProperties": 2}', struct('a', 1),         "object has 1 property, minimum is 2"
                '{"type": "object", "maxProperties": 1}', struct('a', 1, 'b', 2), "object has 2 properties, maximum is 1"
                };
            verifyCases(test, cases);
        end

        function oneOfScalarAndArrayBranches(test)
            % A scalar satisfies an array schema, so it matched both
            % branches, and oneOf (exactly one) refused it. JSON Schema
            % keeps them apart.
            numOrArray = '{"oneOf": [{"type": "number"}, {"type": "array", "items": {"type": "number"}}]}';
            strOrArray = '{"oneOf": [{"type": "string"}, {"type": "array", "items": {"type": "string"}}]}';
            objOrArray = '{"oneOf": [{"type": "object"}, {"type": "array", "items": {"type": "object"}}]}';
            arrayOrStr = '{"oneOf": [{"type": "array", "items": {"type": "number"}}, {"type": "string"}]}';
            twoArrays  = '{"oneOf": [{"type": "array", "items": {"type": "number"}}, {"type": "array", "items": {"type": "integer"}}]}';
            cases = {
                numOrArray, 7,                      ""
                numOrArray, [1; 2],                 ""
                numOrArray, 'x',                    "does not match any of 2 schemas"
                strOrArray, 'abc',                  ""
                strOrArray, {'a'; 'b'},             ""
                objOrArray, struct('x', 1),         ""
                objOrArray, jsondecode('[{"x":1},{"x":2}]'), ""
                % No branch matches as JSON Schema reads it: a scalar is an
                % array of one, as [7] decodes.
                arrayOrStr, 7,                      ""
                twoArrays,  7,                      "value matches 2 schemas (exactly one required)"
                twoArrays,  [1.5; 2],               ""
                % Nested: the branches of a oneOf in items, and an array
                % in a branch.
                ['{"type": "array", "items": ' numOrArray '}'], {7; [1; 2]}, ""
                ['{"oneOf": [{"type": "object", "properties": {"v": {"type": "number"}}, "required": ["v"]}, ' ...
                 '{"type": "object", "properties": {"v": {"type": "array", "items": {"type": "string"}}}, "required": ["v"]}]}'], ...
                    struct('v', 7), ""
                };
            verifyCases(test, cases);
        end

        function anyOfAndTypeListsUnchanged(test)
            cases = {
                '{"anyOf": [{"type": "number"}, {"type": "array", "items": {"type": "number"}}]}', 7, ""
                '{"type": ["number", "array"]}', 7, ""
                '{"allOf": [{"type": "number"}, {"type": "array", "items": {"type": "number"}}]}', 7, ""
                };
            verifyCases(test, cases);
        end

        function typeListsReadOneValueFirst(test)
            % With "array" first in a type list, a single value was read
            % as an array of one: the keywords for strings and numbers
            % didn't limit it, and those for arrays did. Now the order
            % doesn't matter.
            for t = ["[""array"", ""string""]" "[""string"", ""array""]"]
                cases = {
                    '{"type": ' + t + ', "maxLength": 3}',  'abcdef', "string has 6 characters, maximum is 3"
                    '{"type": ' + t + ', "maxLength": 3}',  'abc',    ""
                    '{"type": ' + t + ', "items": {"type": "number"}}', 'abc', ""
                    '{"type": ' + t + ', "minItems": 2}',  {'a'; 'b'}, ""
                    '{"type": ' + t + ', "minItems": 3}',  {'a'; 'b'}, "array has 2 items, minimum is 3"
                    };
                verifyCases(test, cases);
            end
            for t = ["[""array"", ""number""]" "[""number"", ""array""]"]
                cases = {
                    '{"type": ' + t + ', "minimum": 0}',  -5,     "value -5 is less than the minimum, 0"
                    '{"type": ' + t + ', "minItems": 2}', 5,      ""
                    '{"type": ' + t + ', "minItems": 2}', [1; 2], ""
                    '{"type": ' + t + ', "minItems": 3}', [1; 2], "array has 2 items, minimum is 3"
                    '{"type": ' + t + ', "items": {"type": "number"}}', {'a'}, "expected number"
                    };
                verifyCases(test, cases);
            end
            cases = {
                '{"type": ["array", "null"], "minItems": 3}', [],        ""
                '{"type": ["array", "null"], "minItems": 3}', [1; 2; 3], ""
                '{"type": ["array", "null"], "minItems": 3}', [1; 2],    "array has 2 items, minimum is 3"
                '{"type": ["array", "object"], "required": ["a"]}', struct('b', 1), "missing required property 'a'"
                };
            verifyCases(test, cases);
        end

        function arrayKeywordsBesideNull(test)
            % jsondecode gives null as [], and the array keywords beside
            % an alternative that allows null rejected it.
            cases = {
                '{"anyOf": [{"type": "array"}, {"type": "null"}], "minItems": 3}', [],     ""
                '{"anyOf": [{"type": "array"}, {"type": "null"}], "minItems": 3}', [1; 2], "array has 2 items, minimum is 3"
                '{"anyOf": [{"type": "array"}, {"type": ["string", "null"]}], "minItems": 1}', [], ""
                % With no alternative that allows null, [] is an empty array.
                '{"anyOf": [{"type": "array"}, {"type": "number"}], "minItems": 1}', [], "array has 0 items, minimum is 1"
                '{"minItems": 1}', [], "array has 0 items, minimum is 1"
                };
            verifyCases(test, cases);
        end

        function keywordsBesideCombinators(test)
            % Each keyword applies, not only the combinator. With no type,
            % the array keywords don't apply to a single value.
            numOrArray = ['{"anyOf": [{"type": "number"}, {"type": "array", ' ...
                '"items": {"type": "number"}}], "minItems": 3, "maxItems": 3}'];
            cases = {
                '{"anyOf": [{"type": "number"}], "minimum": 5}',     1,     "value 1 is less than the minimum, 5"
                '{"anyOf": [{"type": "number"}], "minimum": 5}',     6,     ""
                '{"oneOf": [{"type": "string"}], "maxLength": 2}',   'abc', "string has 3 characters, maximum is 2"
                '{"allOf": [{"type": "object"}], "required": ["a"]}', struct('b', 1), "missing required property 'a'"
                numOrArray, 7,         ""
                numOrArray, [1; 2; 3], ""
                numOrArray, [1; 2],    "array has 2 items, minimum is 3"
                };
            verifyCases(test, cases);
        end

        % Through toolArgumentError, as tools/call checks arguments

        function builtToolsCheckConstraints(test)
            for enc = ["JSON" "Invertible"]
                f = argumentCheck(test, "schemaBounds", enc);
                test.verifyEqual(f(struct('lower', 0)), "", enc);
                test.verifySubstring(f(struct('lower', -1)), ...
                    "Argument 'lower': value -1 is less than the minimum, 0.", enc);
                test.verifySubstring(f(struct('upper', 11)), ...
                    "is greater than the maximum, 10", enc);
                test.verifySubstring(f(struct('both', 11)), ...
                    "is greater than the maximum, 10", enc);

                f = argumentCheck(test, "schemaStrings", enc);
                test.verifyEqual(f(struct('code', "ABC-12")), "", enc);
                test.verifySubstring(f(struct('code', "abc")), ...
                    "does not match the pattern", enc);
                test.verifySubstring(f(struct('name', "a")), ...
                    "string has 1 character, minimum is 2", enc);
            end
            f = argumentCheck(test, "schemaStrings", "JSON");
            test.verifyEqual(f(struct('tags', {{'a'; 'b'}})), "");
            test.verifySubstring(f(struct('tags', {{'a'; 'a'}})), ...
                "items 1 and 2 are equal");
        end

        function wrappedValuesCheckConstraints(test)
            f = argumentCheck(test, "schemaBounds", "Invertible");
            w = @(v) struct('type', "double", 'size', [1 1], 'data', v);
            test.verifyEqual(f(struct('both', w(5))), "");
            test.verifyGreaterThan(strlength(f(struct('both', w(11)))), 0);
            test.verifyGreaterThan(strlength(f(struct('both', w("Inf")))), 0, ...
                "Inf is above the maximum");
            test.verifyEqual(f(struct('lower', w("Inf"))), "", ...
                "Inf is above the minimum");
        end

        % isJsonSchemaPattern and validateSchemaKeywords

        function jsonSchemaPatterns(test)
            ok = ["^[A-Z]+$" "\d{3}-\d{4}" "(a)\1" ...
                "(?<y>\d+)\k<y>" "\\u" "\\c" "a|" ")" ("\" + "u0041") "\cJ" ...
                "^[A-Za-z0-9_-]+$" "[+-]" "^[\w.+-]+@[\w-]+\.[\w.-]+$" "[\\-]"];
            for p = ok
                [tf, reason] = prodserver.mcp.validation.isJsonSchemaPattern(p);
                test.verifyTrue(tf, p + ": " + reason);
                test.verifyEqual(reason, "", p);
            end
            % ECMAScript has no inline flags: a client that compiles the
            % pattern would reject (?i).
            bad = ["[" "(" "a{2,1}" "\p{L}+" "(?i)abc" "[[:alpha:]]" ...
                "(?@disp(1))" "(??x)" "[a-]\p{L}" "[\d\D]"];
            for p = bad
                [tf, reason] = prodserver.mcp.validation.isJsonSchemaPattern(p);
                test.verifyFalse(tf, p);
                test.verifyGreaterThan(strlength(reason), 0, p);
            end
            test.verifyFalse(prodserver.mcp.validation.isJsonSchemaPattern(3));
            test.verifyFalse(prodserver.mcp.validation.isJsonSchemaPattern(["a" "b"]));
            test.verifyError(@() prodserver.mcp.validation. ...
                mustBeJsonSchemaPattern("\p{L}"), ...
                "prodserver:mcp:InvalidJsonSchemaPattern");
        end

        function keywordValuesTheServerCantCheck(test)
            % A length of null, or a list, raised an error at every call.
            % build rejects them; one that came another way isn't checked.
            cases = {
                '{"type": "string", "maxLength": null}', 'abc', ""
                '{"type": "string", "minLength": [1, 2]}', 'abc', ""
                '{"type": "number", "minimum": null}', 1, ""
                '{"type": "number", "exclusiveMinimum": [true, false]}', 1, ""
                '{"type": "number", "multipleOf": null}', 1, ""
                '{"type": "array", "minItems": null}', [1; 2], ""
                '{"type": "object", "maxProperties": null}', struct('a', 1), ""
                '{"type": "object", "additionalProperties": [false, false]}', struct('a', 1), ""
                };
            verifyCases(test, cases);

            f = @(j) prodserver.mcp.jsonrpc.validateSchemaKeywords(jsondecode(j));
            id = "prodserver:mcp:InvalidSchemaKeyword";
            bad = {'{"maxLength": null}', '{"minLength": -1}', '{"minItems": 1.5}', ...
                '{"maxProperties": "2"}', '{"minimum": null}', '{"maximum": [1, 2]}', ...
                '{"exclusiveMinimum": "0"}', '{"multipleOf": 0}', '{"multipleOf": -2}', ...
                '{"uniqueItems": 1}', '{"items": {"maxItems": null}}', ...
                '{"anyOf": [{"type": "null"}, {"minLength": null}]}', ...
                '{"properties": {"p": {"maximum": "9"}}}'};
            for k = 1:numel(bad)
                test.verifyError(@() f(bad{k}), id, bad{k});
            end
            test.verifyEqual(errorMessage(@() f('{"minLength": null}')), ...
                "The value of minLength must be a non-negative integer, not null.");
            % Valid values, and data that only looks like keywords.
            f(['{"minLength": 0, "maxLength": 3, "minItems": 1, "maximum": -2.5, ' ...
                '"exclusiveMinimum": true, "exclusiveMaximum": 4, "multipleOf": 0.1, ' ...
                '"uniqueItems": false, "maxProperties": 2}']);
            f('{"default": {"maxLength": null}, "const": {"minimum": "a"}}');
            f('{"properties": {"minLength": {"type": "string"}}}');
            % Property names in dependentRequired and dependencies, and an
            % extension's fields, are data: they stopped build.
            f('{"type": "object", "dependencies": {"maximum": ["minimum"]}}');
            f('{"dependentRequired": {"minimum": ["b"], "pattern": ["c"]}}');
            f('{"x-meta": {"minimum": "low", "pattern": "["}}');
            % A schema in dependencies, or under $defs, is still checked.
            test.verifyError(@() f('{"dependencies": {"a": {"maxLength": null}}}'), id);
            test.verifyError(@() f('{"$defs": {"a": {"maxLength": null}}}'), id);
            test.verifyError(@() f('{"dependencies": {"a": {"pattern": "("}}}'), ...
                "prodserver:mcp:InvalidJsonSchemaPattern");
        end

        function schemaPatternsAtAnyDepth(test)
            f = @(j) prodserver.mcp.jsonrpc.validateSchemaKeywords(jsondecode(j));
            id = "prodserver:mcp:InvalidJsonSchemaPattern";
            test.verifyError(@() f('{"pattern": "(?i)a"}'), id);
            test.verifyError(@() f('{"items": {"pattern": "["}}'), id);
            test.verifyError(@() f('{"anyOf": [{"type": "null"}, {"pattern": "["}]}'), id);
            test.verifyError(@() f('{"properties": {"p": {"pattern": "["}}}'), id);
            % Data, and a property named pattern, are not patterns.
            f('{"default": {"pattern": "["}, "examples": [{"pattern": "["}]}');
            f('{"properties": {"pattern": {"type": "string"}}}');
            f('{"pattern": "^[a-z]+$"}');
        end

    end
end

function verifyCases(test, cases)
% Validate each value, cases{k,2}, against the schema cases{k,1}, and
% verify the detail is "" or contains cases{k,3}.
    for k = 1:size(cases, 1)
        detail = prodserver.mcp.validation.validateArgumentsWithSchema( ...
            struct('properties', struct('x', jsondecode(cases{k,1}))), ...
            "x", cases(k,2));
        expected = string(cases{k,3});
        context = string(cases{k,1}) + " with " + jsonencode(cases{k,2});
        if strlength(expected) == 0
            test.verifyEqual(detail, "", context);
        else
            test.verifySubstring(detail, expected, context);
        end
    end
end

function m = errorMessage(f)
% The message of the error F raises, or "" if it raises none.
    m = "";
    try
        f();
    catch err
        m = string(err.message);
    end
end

function f = argumentCheck(~, fcn, encoding)
% toolArgumentError for FCN's tool, built under ENCODING.
    d = prodserver.mcp.internal.mcpDefinition(fcn, fcn, encoding=encoding);
    enc = prodserver.mcp.WireEncoding(encoding);
    f = @(args) prodserver.mcp.validation.toolArgumentError(d.tools, args, enc);
end
