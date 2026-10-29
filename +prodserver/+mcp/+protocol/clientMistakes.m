function ids = clientMistakes()
%clientMistakes Identifier prefixes that blame the caller, not the server.
%   The single enumeration behind isClientMistake. It is a list rather than a
%   chain of comparisons so that it can be iterated: the shared adapter test
%   walks it and holds every revision to it, which is what makes adding a
%   seventh identifier here enough to get it covered on every revision at
%   once. A hand-maintained copy of this list in the tests would defeat that
%   on the first addition.
%
%   Prefixes, not exact identifiers -- callers match with startsWith, so
%   'prodserver:mcp:InvalidParams:missingArguments' is classified by its stem.

% Copyright 2026 The MathWorks, Inc.

    ids = [ ...
        "prodserver:mcp:BadResourceRead"
        "prodserver:mcp:AmbiguousResourceURL"
        "prodserver:mcp:ToolUnavailable"
        "prodserver:mcp:AmbiguousToolName"
        "prodserver:mcp:BadInputArguments"
        "prodserver:mcp:InvalidParams"
        ];
end
