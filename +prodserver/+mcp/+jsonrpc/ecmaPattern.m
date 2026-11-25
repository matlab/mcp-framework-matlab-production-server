function [m, reason] = ecmaPattern(p)
%ecmaPattern MATLAB's form of an ECMAScript regular expression.
%   [m, reason] = ecmaPattern(p) is the regular expression M with which
%   MATLAB's regexp matches what the ECMAScript regular expression P, a
%   JSON Schema pattern, matches. If P uses syntax that has no MATLAB form,
%   or that ECMAScript doesn't have, M is "" and REASON says why;
%   otherwise REASON is "".
%
%   Escapes and characters whose meaning differs are rewritten:
%
%     - \d, \w and \s, and \D, \W and \S, are ECMAScript's sets: ASCII
%       digits and word characters, and ECMAScript's whitespace. MATLAB's
%       \d and \w match other scripts' digits and letters too, and its \s
%       other whitespace. Within brackets, \D, \W and \S have no form, and
%       are rejected, and a hyphen beside \d, \w or \s is the hyphen, as
%       in ECMAScript: [\w-.] is word characters, hyphen and dot.
%     - \b and \B are word boundaries by ASCII word characters; within
%       brackets, \b is a backspace. MATLAB's \< and \> are word
%       boundaries, but ECMAScript's are the characters < and >.
%     - . matches any character but a line terminator: \n, \r, U+2028 or
%       U+2029.
%     - \xHH, \uHHHH, \cX and \0 are the characters they name, as \x{...}:
%       MATLAB reads \x41B as \x{41B}, and has no \u or \c.
%     - [] matches nothing, and [^] any character.
%     - [ within brackets is the character, as \[: MATLAB reads it as the
%       start of brackets within them.
%     - A { that doesn't begin a quantifier, {n}, {n,} or {n,m}, is the
%       character, as \{, as ECMAScript reads it: a{ and x{,3}.
%
%   Rejected: inline flags, such as (?i), and MATLAB's other (? groups,
%   which ECMAScript doesn't have: a client that compiles the pattern would
%   reject it; for the same reason, a possessive quantifier, such as a++ or
%   a{2}+, which ECMAScript has no form of, and a quantifier after a
%   quantifier, such as a+{2}, a** or a+??, which it rejects; \p{...}, which MATLAB doesn't support; a letter escape
%   ECMAScript doesn't define, such as \a; an octal escape such as \01;
%   a backreference to a group the pattern doesn't have, such as \8 with
%   fewer than eight, which ECMAScript reads as a character; one above \9,
%   which MATLAB can't match (\k<name> can); \1 to \9 within brackets,
%   which are octal escapes in ECMAScript, or for 8 and 9, the digit; a
%   POSIX class such as [:alpha:] within brackets, which isn't one in
%   ECMAScript; and a range out of order, such as [z-a], which ECMAScript
%   rejects too.
%
%   ecmaPattern doesn't check that P is otherwise well formed:
%   isJsonSchemaPattern does, with M.

% Copyright 2026 The MathWorks, Inc.

    word = 'A-Za-z0-9_';
    space = ['\t\n\v\f\r \x{A0}\x{1680}\x{2000}-\x{200A}\x{2028}' ...
        '\x{2029}\x{202F}\x{205F}\x{3000}\x{FEFF}'];
    boundary = ['(?:(?<=[' word '])(?![' word '])|(?<![' word '])(?=[' word ']))'];
    notBoundary = ['(?:(?<=[' word '])(?=[' word '])|(?<![' word '])(?![' word ']))'];

    m = "";
    reason = "";
    p = char(p);
    n = numel(p);
    [groups, named] = captureGroups(p);
    parts = cell(1, n);
    k = 0;
    inClass = false;
    % Within brackets, the atoms -- a character, a set such as \d, or a
    % hyphen -- are collected, and written at the ], when it is known which
    % hyphens make ranges (classBody).
    opening = '';
    atoms = cell(0, 3);
    i = 1;
    % What the token before this one, outside brackets, was: "greedy", a
    % quantifier; "lazy", the ? that made one lazy; or "" for anything
    % else. A ? after a greedy quantifier makes it lazy; a + makes it
    % possessive; any other quantifier after either has nothing to repeat.
    previous = "";
    while i <= n
        c = p(i);
        kind = 'char';
        from = i;
        wasInClass = inClass;
        kind_ = "";
        if c == '\'
            if i == n
                reason = "The pattern ends with a backslash.";
                return
            end
            e = p(i+1);
            i = i + 2;
            switch e
                case 'd'
                    piece = classOf('0-9', inClass);
                case 'w'
                    piece = classOf(word, inClass);
                case 's'
                    piece = classOf(space, inClass);
                case {'D', 'W', 'S'}
                    if inClass
                        reason = "MATLAB has no form of \" + e + ...
                            " within brackets. List the characters instead.";
                        return
                    end
                    sets = struct('D', '0-9', 'W', word, 'S', space);
                    piece = ['[^' sets.(e) ']'];
                case 'b'
                    if inClass
                        piece = '\x{8}';
                    else
                        piece = boundary;
                    end
                case 'B'
                    if inClass
                        reason = "\B within brackets isn't an ECMAScript escape.";
                        return
                    end
                    piece = notBoundary;
                case 'x'
                    [piece, i, reason] = hexCode(p, i, 2, "\x");
                case 'u'
                    [piece, i, reason] = hexCode(p, i, 4, "\u");
                case 'c'
                    if i > n || ~any(p(i) == ['A':'Z' 'a':'z'])
                        reason = "\c must be followed by a letter.";
                        return
                    end
                    piece = sprintf('\\x{%X}', mod(double(p(i)), 32));
                    i = i + 1;
                case '0'
                    if i <= n && isDigit(p(i))
                        reason = "ECMAScript's octal escapes, such as \0" + ...
                            p(i) + ", aren't JSON Schema patterns.";
                        return
                    end
                    piece = '\x{0}';
                case {'1', '2', '3', '4', '5', '6', '7', '8', '9'}
                    % A backreference, as MATLAB writes it, to a group the
                    % pattern has. ECMAScript reads \8, with fewer groups,
                    % as a character; MATLAB, as a backreference. Within
                    % brackets, ECMAScript reads \1 as an octal escape.
                    if inClass && any(e == '89')
                        reason = "Within brackets, \" + e + " is the " + ...
                            "character " + e + " in ECMAScript. Write " + e + ".";
                        return
                    elseif inClass
                        reason = "Within brackets, \" + e + " is an octal " + ...
                            "escape in ECMAScript, which JSON Schema patterns " + ...
                            "don't use. Write the character, or \xHH.";
                        return
                    end
                    j = i;
                    while j <= n && isDigit(p(j))
                        j = j + 1;
                    end
                    group = str2double([e p(i:j-1)]);
                    if group > 9
                        % MATLAB reads \10 as \1 and 0.
                        reason = "MATLAB's backreferences reach the first " + ...
                            "nine groups only, so it can't match \" + group + ...
                            ". Name the group, (?<name>...), and refer to it " + ...
                            "as \k<name>.";
                        return
                    end
                    if group > groups
                        reason = "\" + group + " refers to group " + group + ...
                            ", but the pattern has " + groups + ...
                            ", so ECMAScript reads it as a character, not " + ...
                            "a backreference. Write the character instead.";
                        return
                    end
                    piece = ['\' e p(i:j-1)];
                    i = j;
                case 'k'
                    % In a pattern with a named group, \k<name> is a
                    % backreference, as in MATLAB, and \k within brackets
                    % is an error. In one without, ECMAScript reads \k as
                    % the character k: \k<n> is the text k<n>.
                    if inClass && named
                        reason = "Within brackets, \k isn't an escape " + ...
                            "ECMAScript allows in a pattern with a named group.";
                        return
                    elseif named
                        piece = '\k';
                    else
                        piece = 'k';
                    end
                case {'f', 'n', 'r', 't', 'v'}
                    piece = ['\' e];
                case {'p', 'P'}
                    reason = "MATLAB doesn't support \" + e + ...
                        "{...}. Use a character range instead, such as [A-Za-z].";
                    return
                case {'<', '>'}
                    piece = e;
                otherwise
                    if any(e == ['A':'Z' 'a':'z' '0':'9'])
                        reason = "\" + e + " isn't an ECMAScript escape.";
                        return
                    end
                    piece = ['\' e];
            end
            if strlength(reason) > 0
                return
            end
            if inClass && any(e == 'dws')
                kind = 'set';
            end
        elseif inClass
            i = i + 1;
            if c == ']'
                inClass = false;
                [body, reason] = classBody(atoms);
                if strlength(reason) > 0
                    return
                end
                piece = [opening body ']'];
            elseif c == '-'
                kind = 'hyphen';
                piece = '\-';
            elseif c == '[' && ~isempty(regexp(p(i:end), '^:[A-Za-z]+:\]', 'once'))
                reason = "ECMAScript has no POSIX classes: [:" + ...
                    " within brackets is the characters [ and :, " + ...
                    "not the start of a class such as [:alpha:]. Use " + ...
                    "a range, such as [A-Za-z], or write \[ for the " + ...
                    "character.";
                return
            elseif c == '['
                % A [ within brackets is the character in ECMAScript; in
                % MATLAB, it begins brackets within them.
                piece = '\[';
            else
                piece = c;
            end
        elseif c == '['
            if startsWith(p(i:end), '[]')
                piece = '(?!)';
                i = i + 2;
            elseif startsWith(p(i:end), '[^]')
                piece = '[\x{0}-\x{FFFF}]';
                i = i + 3;
            else
                % A ] first, or after ^, ends the brackets in ECMAScript:
                % [] and [^] are handled above.
                inClass = true;
                piece = c;
                i = i + 1;
                if i <= n && p(i) == '^'
                    piece = '[^';
                    i = i + 1;
                end
            end
        elseif c == '.'
            piece = '[^\n\r\x{2028}\x{2029}]';
            i = i + 1;
        elseif c == '(' && i < n && p(i+1) == '?'
            group = regexp(p(i:end), '^\(\?(:|=|!|<=|<!|<[A-Za-z_$])', 'match', 'once');
            if isempty(group)
                if i + 2 <= n && any(p(i+2) == '@?')
                    reason = "Dynamic MATLAB expressions are not allowed.";
                else
                    reason = "ECMAScript has no (?" + p(min(i+2, n)) + ...
                        " group. For inline flags such as (?i), list the " + ...
                        "cases instead, such as [Aa].";
                end
                return
            end
            % A name's first character is copied with the rest of it.
            piece = group;
            i = i + numel(group);
        elseif c == '{'
            % A quantifier, or in ECMAScript, the character.
            q = regexp(p(i:end), '^\{\d+(,\d*)?\}', 'match', 'once');
            if isempty(q)
                piece = '\{';
                i = i + 1;
            else
                if previous ~= ""
                    reason = repeated(p(from:from+numel(q)-1));
                    return
                end
                piece = q;
                i = i + numel(q);
                kind_ = "greedy";
            end
        else
            if any(c == '*+?')
                if c == '?' && previous == "greedy"
                    kind_ = "lazy";
                elseif c == '+' && previous == "greedy"
                    reason = possessive();
                    return
                elseif previous ~= ""
                    reason = repeated(c);
                    return
                else
                    kind_ = "greedy";
                end
            end
            piece = c;
            i = i + 1;
        end
        if inClass
            previous = "";
        else
            previous = kind_;
        end
        if wasInClass && inClass
            atoms(end+1, :) = {kind, piece, p(from:i-1)}; %#ok<AGROW>
        elseif inClass
            % [ or [^: the brackets begin.
            opening = piece;
            atoms = cell(0, 3);
        else
            k = k + 1;
            parts{k} = piece;
        end
    end
    if inClass
        % No ]: regexpPattern rejects the brackets, as isJsonSchemaPattern
        % checks.
        k = k + 1;
        [body, reason] = classBody(atoms);
        if strlength(reason) > 0
            return
        end
        parts{k} = [opening body];
    end
    m = string(['' parts{:}]);
end

function reason = possessive()
% Why a possessive quantifier, such as a++, is rejected.
    reason = "ECMAScript has no possessive quantifiers, such as a++ " + ...
        "or a{2}+, so a client that compiles the pattern would reject " + ...
        "it. Leave out the second +, or for a literal +, write \+.";
end

function reason = repeated(q)
% Why a quantifier, Q, after another is rejected.
    reason = "The quantifier " + string(q) + " follows another, as in " + ...
        "a+{2} or a**, and ECMAScript rejects it: there's nothing for it " + ...
        "to repeat. To repeat a repeated part, group it, as in (?:a+){2}.";
end

function [body, reason] = classBody(atoms)
% The atoms of brackets, written as MATLAB reads them: each a character, a
% set such as \d, or a hyphen, and A-B a range, as ECMAScript reads them --
% unless A or B is a set, which makes A, the hyphen and B each a member
% (Annex B): [\w-.] is word characters, hyphen and dot. Any other hyphen is
% the character, \-, as is one at either end: [a-], [-a].
    body = '';
    reason = "";
    j = 1;
    count = size(atoms, 1);
    while j <= count
        if j + 2 <= count && strcmp(atoms{j+1, 1}, 'hyphen')
            if strcmp(atoms{j, 1}, 'set') || strcmp(atoms{j+2, 1}, 'set')
                body = [body atoms{j, 2} '\-' atoms{j+2, 2}]; %#ok<AGROW>
            else
                % ECMAScript rejects a range whose ends are out of order.
                from = atomCode(atoms{j, 2});
                to = atomCode(atoms{j+2, 2});
                ends = {atoms{j, 3}, atoms{j+2, 3}};
                halves = cellfun(@(e) isscalar(e) && e >= 0xD800 && e <= 0xDFFF, ends);
                if from > to && any(halves)
                    % As written, half of a character outside the Basic
                    % Multilingual Plane, such as an emoji: not \uD800.
                    reason = "A range within brackets ends in a character " + ...
                        "outside the Basic Multilingual Plane, such as an " + ...
                        "emoji, which ECMAScript reads as two characters, " + ...
                        "so the range is out of order. List such " + ...
                        "characters as alternatives instead, (a|b).";
                    return
                elseif from > to
                    reason = "The range " + atoms{j, 3} + "-" + atoms{j+2, 3} + ...
                        " within brackets is out of order, which ECMAScript " + ...
                        "rejects.";
                    return
                end
                body = [body atoms{j, 2} '-' atoms{j+2, 2}]; %#ok<AGROW>
            end
            j = j + 3;
        else
            body = [body atoms{j, 2}]; %#ok<AGROW>
            j = j + 1;
        end
    end
end

function piece = classOf(set, inClass)
% SET within brackets as it is, or outside them, in them.
    if inClass
        piece = set;
    else
        piece = ['[' set ']'];
    end
end

function [piece, i, reason] = hexCode(p, i, digits, name)
% The character the DIGITS hexadecimal digits at P(I) name, as \x{...}.
    piece = '';
    reason = "";
    hex = p(i:min(i + digits - 1, numel(p)));
    if numel(hex) < digits || ~all(isstrprop(hex, 'xdigit'))
        reason = name + " must be followed by " + digits + ...
            " hexadecimal digits.";
        return
    end
    piece = ['\x{' upper(hex) '}'];
    i = i + digits;
end

function [count, named] = captureGroups(p)
% The number of capturing groups in the pattern P, named or not, and whether
% one is named, (?<name>...): each ( not
% within brackets or escaped, and not (?: or a lookaround. ECMAScript counts
% every group in the pattern, before or after a backreference, so they are
% counted first. (A backreference to a group that hasn't matched, or not
% yet, still differs: ECMAScript matches it as empty; MATLAB, as nothing.)
    count = 0;
    named = false;
    inClass = false;
    i = 1;
    n = numel(p);
    while i <= n
        c = p(i);
        if c == '\'
            i = i + 2;
            continue
        end
        if inClass
            inClass = c ~= ']';
        elseif c == '['
            inClass = true;
            % A ] first is the end of [] in ECMAScript, which ecmaPattern
            % reads too; [^] likewise.
            if i < n && p(i+1) == '^'
                i = i + 1;
            end
            if i < n && p(i+1) == ']'
                inClass = false;
                i = i + 1;
            end
        elseif c == '('
            if i == n || p(i+1) ~= '?'
                count = count + 1;
            elseif i + 2 <= n && p(i+2) == '<' && ...
                    ~(i + 3 <= n && any(p(i+3) == '=!'))
                count = count + 1;
                named = true;
            end
        end
        i = i + 1;
    end
end

function code = atomCode(atom)
% The code of the character ATOM, an atom within brackets as ecmaPattern
% writes it: the character, \x{...}, or an escape such as \- or \n. NaN if
% it is none of those.
    code = NaN;
    if isscalar(atom)
        code = double(atom);
    elseif startsWith(atom, '\x{') && endsWith(atom, '}')
        code = hex2dec(atom(4:end-1));
    elseif numel(atom) == 2 && atom(1) == '\'
        controls = struct('t', 9, 'n', 10, 'v', 11, 'f', 12, 'r', 13);
        if isfield(controls, atom(2))
            code = controls.(atom(2));
        elseif ~any(atom(2) == ['A':'Z' 'a':'z' '0':'9'])
            code = double(atom(2));
        end
    end
end

function tf = isDigit(c)
    tf = c >= '0' && c <= '9';
end
