function [tf, reason] = isJsonSchemaPattern(x)
% isJsonSchemaPattern Is X a JSON Schema pattern?
%   [tf, reason] = isJsonSchemaPattern(x) is true if X is a regular
%   expression that MATLAB's regexp matches as JSON Schema's pattern keyword
%   means it, in the form prodserver.mcp.jsonrpc.ecmaPattern gives it. If
%   not, REASON says why; otherwise it is "".
%
%   JSON Schema's patterns are ECMAScript regular expressions. regexp
%   raises no error for a pattern it can't parse: it matches what it can't
%   parse literally, so the check can't simply try the pattern. It is false
%   for:
%
%     - a MATLAB dynamic expression, (?@cmd) or (??expr), which would run
%       code on the server;
%     - a pattern ecmaPattern has no MATLAB form of, such as \p{L}, or
%       rejects, such as the inline flag (?i), which ECMAScript doesn't
%       have, or [:alpha:] within brackets, which isn't the POSIX class
%       it looks like;
%     - a pattern whose MATLAB form regexpPattern rejects, such as "[",
%       except for a backreference, which regexpPattern doesn't support but
%       regexp does, and a literal hyphen at the end of a character class,
%       [a-], which regexpPattern calls an unbound range.
%
%   Some patterns that are invalid in ECMAScript, such as ")" or "*a", are
%   true: regexp matches them literally.

% Copyright 2026 The MathWorks, Inc.

    tf = false;
    if ~(ischar(x) && (isrow(x) || isempty(x))) && ~(isstring(x) && isscalar(x))
        reason = "A pattern must be a single text string.";
        return
    end
    p = string(x);

    if contains(p, ["(?@" "(??"])
        reason = "Dynamic MATLAB expressions are not allowed.";
        return
    end

    [m, reason] = prodserver.mcp.jsonrpc.ecmaPattern(p);
    if strlength(reason) > 0
        return
    end

    % regexpPattern rejects a literal hyphen at the end of a character
    % class, [a-], which ECMAScript and regexp allow, so escape it first.
    % An unescaped hyphen is one preceded by an even number of backslashes.
    try
        regexpPattern(regexprep(m, '(?<!\\)((\\\\)*)-\]', '$1\\-]'));
    catch err
        if err.identifier ~= "MATLAB:pattern:BackreferenceNotSupported"
            reason = string(strtrim(splitlines(err.message)));
            reason = reason(1);
            return
        end
    end

    tf = true;
    reason = "";
end
