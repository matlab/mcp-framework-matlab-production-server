function s = echo(v, opts)
%echo Bounded quote of caller text for a client message, error.data or a log line.
%
%   S = prodserver.mcp.protocol.echo(V):
%   - text (isTextScalar: a string scalar, a char row vector or ''): quoted in backticks,
%     with control characters escaped as \n, \r, \t or \uXXXX (see
%     escapeControl), and a backtick as \u0060, so the quote can't be
%     closed early and the text after it read as the line's. Text longer
%     than MCPConstants.MaxEchoChars (128) characters is cut, the quote ends
%     with "…", and the full length follows outside the quote:
%       `aaaa…` (1048576 characters)
%   - any other value: described by size and class only, never quoted:
%       a 1×480000 double array
%
%   S = echo(V, quoted=false) is the same text without the backticks, and
%   with a space escaped as \u0020 too, so S is one token: the logger's
%   id= and trace= fields use it. A cut text ends with "…(<n>)", the full
%   length in characters; a described value has its spaces escaped too.
%
%   Callers put S in their text as it is. A character is one element of
%   a MATLAB string.
%
%   See also prodserver.mcp.validation.isTextScalar

% Copyright 2026 The MathWorks, Inc.

% Contract:
%   Kind:      query
%   Requires:  none (any value)
%   Ensures:   s is a string scalar of at most MaxEchoChars characters of V's text, plus
%              the backticks, the ellipsis and the length note
%              s holds no control character; with quoted=false, no space either
%   Raises:    none

    % v has no type: any value is accepted, and one that isn't text is described, not converted.
    arguments
        v                                   % any value
        opts.quoted (1,1) logical = true
    end

    if ~prodserver.mcp.validation.isTextScalar(v)
        s = describe(v);
        if ~opts.quoted
            s = replace(s, " ", "\u0020");
        end
        return
    end
    text = string(v);
    n = strlength(text);
    limit = prodserver.mcp.MCPConstants.MaxEchoChars;
    cut = n > limit;
    if cut
        text = extractBefore(text, limit + 1);
    end
    text = prodserver.mcp.internal.escapeControl(text);
    if opts.quoted
        text = replace(text, "`", "\u0060");
        s = "`" + text + "`";
        if cut
            s = "`" + text + "…` (" + n + " characters)";
        end
    else
        s = replace(text, " ", "\u0020");
        if cut
            s = s + "…(" + n + ")";
        end
    end
end

function s = describe(v)
    sz = join(string(size(v)), "×");
    cls = string(class(v));
    if isempty(v)
        s = "an empty " + sz + " " + cls + " array";
    else
        s = "a " + sz + " " + cls + " array";
    end
end
