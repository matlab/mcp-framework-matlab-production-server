function t = escapeControl(t)
%escapeControl Text with its control characters escaped.
%
%   T = prodserver.mcp.internal.escapeControl(T) writes newline, carriage
%   return and tab as \n, \r and \t, and every other character below 32,
%   and 127, as \u00XX, so the text is one line. So are the characters
%   that some viewers break a line at, or that reorder or restyle what a
%   terminal shows: the C1 controls, U+0080 to U+009F, which include NEL
%   and CSI; the line and paragraph separators, U+2028 and U+2029; and the
%   bidirectional controls, U+202A to U+202E and U+2066 to U+2069, as
%   \uXXXX. echo and the logger share it. T is a string scalar.
%
%   See also prodserver.mcp.protocol.echo, prodserver.mcp.logging.Log

% Copyright 2026 The MathWorks, Inc.

% Contract:
%   Kind:      query
%   Requires:  t is text  (internal)
%   Ensures:   t holds no character below 32, no 127 to 159, and none of
%              U+2028, U+2029, U+202A to U+202E or U+2066 to U+2069
%   Raises:    none

    c = char(t);
    bad = c < 32 | (c >= 127 & c <= 159) | c == 8232 | c == 8233 | ...
        (c >= 8234 & c <= 8238) | (c >= 8294 & c <= 8297);
    if ~any(bad)
        t = string(t);
        return
    end
    parts = cell(1, numel(c));
    for k = 1:numel(c)
        switch c(k)
            case newline,   parts{k} = '\n';
            case char(13),  parts{k} = '\r';
            case char(9),   parts{k} = '\t';
            otherwise
                if bad(k)
                    parts{k} = sprintf('\\u%04X', double(c(k)));
                else
                    parts{k} = c(k);
                end
        end
    end
    t = string([parts{:}]);
end
