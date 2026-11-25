classdef tEcmaPattern < matlab.unittest.TestCase
%tEcmaPattern Verify that a JSON Schema pattern, an ECMAScript regular
%expression, matches in MATLAB's form what it matches in ECMAScript.
%   MATLAB's regexp read \b, \<, \x41B, \d, \w, \s and . otherwise than
%   ECMAScript, and didn't support \uHHHH or \cX, so the server accepted
%   arguments a pattern rejects, and rejected some it accepts.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function matchesAsECMAScriptDoes(test)
            % Each pattern, a string, and whether ECMAScript's RegExp (in
            % Node.js) matches it.
            cases = {
                '\bcat\b', 'cat', true
                '\bcat\b', 'a cat.', true
                '\bcat\b', 'xcatx', false
                '\bcat\b', char([0xE9 0x63 0x61 0x74 0xE9]), true
                '\Bat', 'cat', true
                '\Bat', 'at', false
                '^\B$', '', true
                '^\<b\>$', '<b>', true
                '^\<b\>$', 'b', false
                '^\x41B$', 'AB', true
                '^\x41$', 'A', true
                '^\u00e9$', char([0xE9]), true
                '^\u0041B$', 'AB', true
                '^\cJ$', char([0xA]), true
                '^\cj$', char([0xA]), true
                '^\d+$', '123', true
                '^\d+$', char([0x661 0x662 0x663]), false
                '^\w+$', 'abc_1', true
                '^\w+$', char([0x63 0x61 0x66 0xE9]), false
                '^\D$', 'a', true
                '^\D$', '1', false
                '^\W$', char([0xE9]), true
                '^\W$', 'a', false
                '^\s$', ' ', true
                '^\s$', char([0xA0]), true
                '^\s$', char([0xFEFF]), true
                '^\s$', char([0x1680]), true
                '^\s$', char([0x2028]), true
                '^\s$', char([0x2029]), true
                '^\s$', char([0x202F]), true
                '^\s$', char([0x85]), false
                '^\S$', char([0xFEFF]), false
                '^\S$', 'a', true
                '^[\d]+$', '42', true
                '^[\d]+$', char([0x664]), false
                '^[\w.-]+$', 'a.b-c', true
                '^[\w.-]+$', char([0xE9]), false
                '^[^\w]$', char([0xE9]), true
                '^[^\w]$', 'a', false
                '^[\s,]+$', char([0x20 0x2C 0x9]), true
                '^[\s]$', char([0x3000]), true
                '^[\b]$', char([0x8]), true
                '^a.c$', 'abc', true
                '^a.c$', char([0x61 0xA 0x63]), false
                '^a.c$', char([0x61 0xD 0x63]), false
                '^a.c$', 'a c', true
                '^a.c$', char([0x61 0x85 0x63]), true
                '^a.c$', ['a' char(0x2028) 'c'], false
                '^a.c$', ['a' char(0x2029) 'c'], false
                '^[.]$', '.', true
                '^[.]$', 'a', false
                'a[]b', 'ab', false
                '^a[^]b$', char([0x61 0xA 0x62]), true
                '^[^]$', 'x', true
                '^(a)\1$', 'aa', true
                '^(?<y>\d+)-\k<y>$', '12-12', true
                '^(?<y>\d+)-\k<y>$', '12-13', false
                '(?<=\$)\d+', '$42', true
                '(?<!\$)\b\d+', '$42', false
                '^(?:ab)+$', 'abab', true
                '^a(?=b)', 'ab', true
                '^a(?!b)', 'ab', false
                '^\0$', char([0x0]), true
                '^\t\n\v\f\r$', char([0x9 0xA 0xB 0xC 0xD]), true
                '^\.\-\/\\$', '.-/\', true
                '^\$\^\*\+\?\(\)\[\]\{\}\|$', '$^*+?()[]{}|', true
                '^[A-Z]{3}-\d{2}$', 'ABC-12', true
                '^[+-]?\d+$', '-5', true
                '^[a-]$', '-', true
                '^[\\-]$', '-', true
                '^\\u$', '\u', true
                '^\\c$', '\c', true
                '^\\d$', '\d', true
                '^[\w.+-]+@[\w-]+\.[\w.-]+$', 'a.b+c@ex-ample.co.uk', true
                '^[\x41-\x43]+$', 'ABC', true
                '^[\u0041-\u0043]+$', 'ABCD', false
                'a$', char([0x61 0xA]), false
                '^b', char([0x61 0xA 0x62]), false
                '^[\w-.]+$', '-', true
                '^[\w-.]+$', 'a.b-c', true
                '^[\w-@]$', '-', true
                '^[\w-@]$', '@', true
                '^[\w-@]$', '_', true
                '^[\s-z]$', '-', true
                '^[\s-z]$', 'y', false
                '^[a-\d]$', '-', true
                '^[a-\d]$', 'b', false
                '^[a-\d]$', '5', true
                '^[\d-]$', '-', true
                '^[\w-]+$', 'a-b', true
                '^[\d-\w]+$', '-x', true
                '^[a[b]c]$', 'c', false
                '^[a[b]c]$', 'ac]', true
                '^[^[]+$', 'ab', true
                '^[^[]+$', 'a[b', false
                '^[[]$', '[', true
                '^[\d-a-z]$', 'b', false
                '^[\d-a-z]$', '-', true
                '^[\d-a-z]$', 'z', true
                '^[\d-a-z]$', '5', true
                '^[\s-a-c]$', 'b', false
                '^[\s-a-c]$', 'c', true
                '^[!--]$', '+', true
                '^[--a]$', 'Z', true
                '^[a-c-e]$', '-', true
                '^[a-c-e]$', 'd', false
                '^[\d-\w]$', '-', true
                '^[\d-\w]$', 'x', true
                '^[\w-]$', '-', true
                '^[-\w]$', '-', true
                '^[a\-z]$', 'b', false
                '^[\]-a]$', '_', true
                '^[\x41-\x43-]$', '-', true
                '^[\b-\d]$', '-', true
                '^(?<n>a)(b)(c)(d)(e)(f)(g)(h)(i)(j)\k<n>$', 'abcdefghija', true
                '^[\[\]]$', ']', true
                '^[\]a]$', ']', true
                '^(a)(b)\2\1$', 'abba', true
                '^(?<n>a)\1$', 'aa', true
                '^(?:a)(b)\1$', 'abb', true
                '^(?=a)(a)\1$', 'aa', true
                '^[(](a)\1$', '(aa', true
                '^[a[:]$', 'a', true
                '^[a[:]$', ':', true
                '^[a[:]$', '[', true
                '^[\w.[:-]+$', 'a:[-', true
                '^[!-\-]$', '+', true
                '^[\x41-\x5A]$', 'Q', true
                '^[\t-\r]$', char([0xB]), true
                '^[ -~]+$', 'a b~', true
                '^[\k]$', 'k', true
                '^[a\k]+$', 'kak', true
                '^[\k-z]$', 'm', true
                '^[(?<a][\k]$', 'ak', true
                '^[(?<a][\k]$', 'kk', false
                '^\k<n>$', 'k<n>', true
                '^\k$', 'k', true
                '^a\kb$', 'akb', true
                '^$', '', true
                'a*', 'b', true
                '^[a-z]*$', '', true
                'x', '', false
                '\b', '', false
                '\B', '', true
                '^a+?b$', 'aab', true
                '^a??b$', 'b', true
                '^a*?b$', 'aab', true
                '^(?:a+){2}$', 'aaa', true
                '^a+[+]$', 'aa+', true
                '^a+\+$', 'aa+', true
                '^a{1,2}?$', 'a', true
                '^[a+]+$', 'a+a', true
                '^\++$', '++', true
                '^(ab)+$', 'abab', true
                '^a{2}$', 'aa', true
                '^a{2,}$', 'aaa', true
                '^a{$', 'a{', true
                '^x{,3}$', 'x{,3}', true
                '^x{,3}$', 'xxx', false
                '^a{1$', 'a{1', true
                '^a}$', 'a}', true
                };
            for k = 1:size(cases, 1)
                [p, s, expected] = cases{k,:};
                context = string(p) + " with " + jsonencode(s);
                [tf, reason] = prodserver.mcp.validation.isJsonSchemaPattern(p);
                test.verifyTrue(tf, context + ": " + reason);
                [m, reason] = prodserver.mcp.jsonrpc.ecmaPattern(p);
                test.verifyEqual(reason, "", context);
                test.verifyEqual(~isempty(regexp(s, m, 'once', 'emptymatch')), ...
                    expected, context + " as " + m);
            end
        end

        function forms(test)
            E = @prodserver.mcp.jsonrpc.ecmaPattern;
            test.verifyEqual(E('\x41B'), "\x{41}B");
            test.verifyEqual(E('\cJ'), "\x{A}");
            test.verifyEqual(E('[\d]'), "[0-9]");
            test.verifyEqual(E('\d'), "[0-9]");
            test.verifyEqual(E('[\w-.]'), "[A-Za-z0-9_\-.]", "a hyphen after a set");
            test.verifyEqual(E('[a-\d]'), "[a\-0-9]", "a hyphen before a set");
            test.verifyEqual(E('[a-z]'), "[a-z]", "a range, as it is");
            test.verifyEqual(E('[\d-a-z]'), "[0-9\-a\-z]", "a set's hyphen, then the next");
            test.verifyEqual(E('[a-c-e]'), "[a-c\-e]", "a range, then a hyphen");
            test.verifyEqual(E('[-a-]'), "[\-a\-]", "hyphens at the ends");
            test.verifyEqual(E('[^[]'), "[^\[]", "a [ within brackets");
            test.verifyEqual(E('[\k]'), "[k]", "\k within brackets is k");
            test.verifyEqual(E('(?<n>a)\k<n>'), "(?<n>a)\k<n>", "outside, as it is");
            test.verifyEqual(E('\k<n>'), "k<n>", "with no named group, the text");
            test.verifyEqual(E('[(?<a][\k]'), "[(?<a][k]", "a (?< within brackets names nothing");
            test.verifyEqual(E('[\[]'), "[\[]", "escaped already");
            test.verifyEqual(E('^[A-Z]{3}-\d{2}$'), "^[A-Z]{3}-[0-9]{2}$");
            test.verifyEqual(E('a\.b\-c\\'), "a\.b\-c\\", "escaped punctuation");
            test.verifyEqual(E('(?<y>a)\k<y>(?:b)(?=c)(?!d)(?<=e)(?<!f)\1'), ...
                "(?<y>a)\k<y>(?:b)(?=c)(?!d)(?<=e)(?<!f)\1", "groups as they are");
            test.verifyEqual(E('a{'), "a\{", "a { that begins no quantifier");
            test.verifyEqual(E('a{2,3}'), "a{2,3}", "a quantifier, as it is");
            test.verifyEqual(E(""), "");
            test.verifyEqual(E("abc"), "abc", "text");
        end

        function noMATLABForm(test)
            % Each pattern, and part of the reason it is rejected.
            cases = {
                '(?i)abc',      "no (?i group"
                '(?-i)abc',     "no (?- group"
                '(?#note)a',    "no (?# group"
                '(?>a)',        "no (?> group"
                '(?@disp(1))',  "Dynamic MATLAB expressions"
                '\p{L}',        "doesn't support \p{...}"
                '\P{L}',        "doesn't support \P{...}"
                '[\D]',         "no form of \D within brackets"
                '[\W]',         "no form of \W within brackets"
                '[\S]',         "no form of \S within brackets"
                '[\B]',         "\B within brackets"
                '\a',           "\a isn't an ECMAScript escape"
                '\e',           "\e isn't an ECMAScript escape"
                '\x4',          "\x must be followed by 2 hexadecimal digits"
                '\u12',         "\u must be followed by 4 hexadecimal digits"
                '\u{41}',       "\u must be followed by 4 hexadecimal digits"
                '\c1',          "\c must be followed by a letter"
                '\01',          "octal escapes"
                'a\',           "ends with a backslash"
                '\8',           "\8 refers to group 8, but the pattern has 0"
                '(a)\2',        "\2 refers to group 2, but the pattern has 1"
                '(?:a)(?=b)\1', "but the pattern has 0"
                '[(]\1',        "but the pattern has 0"
                '\(a\)\1',      "but the pattern has 0"
                '(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)\10', "first nine groups only"
                '(a)[\1]',      "Within brackets, \1 is an octal escape"
                '[\8]',         "Within brackets, \8 is the character 8"
                '[z-a]',        "The range z-a within brackets is out of order"
                '[a-\-]',       "out of order"
                '[\x5A-\x41]',  "out of order"
                '[a-[]',        "out of order"
                % Its message quotes the pattern, not its MATLAB form.
                '[\cZ-\cA]',    "The range \cZ-\cA within brackets is out of order"
                '[\k-a]',       "The range \k-a within brackets is out of order"
                ['[' char([0xD83D 0xDE00]) '-' char([0xD83D 0xDE0E]) ']'], ...
                                "outside the Basic Multilingual Plane"
                '(?<n>a)[\k]',  "Within brackets, \k isn't an escape"
                % Escapes of surrogates are no emoji.
                '[\uDE00-\uD800]', "The range \uDE00-\uD800 within brackets is out of order"
                '[[:alpha:]]',  "ECMAScript has no POSIX classes"
                '[a[:digit:]]', "ECMAScript has no POSIX classes"
                'a++',          "no possessive quantifiers"
                'a*+',          "no possessive quantifiers"
                'a?+',          "no possessive quantifiers"
                'a{2}+',        "no possessive quantifiers"
                'a{2,}+',       "no possessive quantifiers"
                '(ab)++',       "no possessive quantifiers"
                'a+{2}',        "The quantifier {2} follows another"
                'a{2}{3}',      "The quantifier {3} follows another"
                'a**',          "The quantifier * follows another"
                'a+*',          "The quantifier * follows another"
                'a+??',         "The quantifier ? follows another"
                'a*?+',         "The quantifier + follows another"
                'a{1,2}?{3}',   "The quantifier {3} follows another"
                };
            for k = 1:size(cases, 1)
                [m, reason] = prodserver.mcp.jsonrpc.ecmaPattern(cases{k,1});
                test.verifyEqual(m, "", cases{k,1});
                test.verifySubstring(reason, cases{k,2}, cases{k,1});
                [tf, why] = prodserver.mcp.validation.isJsonSchemaPattern(cases{k,1});
                test.verifyFalse(tf, cases{k,1});
                test.verifyEqual(why, reason, cases{k,1});
            end
        end

    end
end
