function json = restoreFieldNames(json, pairs)
%restoreFieldNames Replace MATLAB-mangled field names with MCP wire names.
%   PAIRS is an Nx2 cell array of {mangledName, wireName}. Each mangled name
%   is replaced with its wire name wherever it is an object key in JSON.
%
%   MCP wire field names contain characters that are not legal in a MATLAB
%   struct field name ('_meta', 'io.modelcontextprotocol/ui'), so the
%   framework builds responses using a mangled stand-in and swaps the real
%   name back in after jsonencode. Every revision needs that substitution;
%   only the table differs, which is why the loop lives here and the tables
%   live with the revisions that own them.
%
%   Only keys are renamed: a key follows { or , (and perhaps whitespace)
%   and is followed by a colon. The same text inside a string value is
%   escaped by jsonencode as \"name\", so it is left alone.

% Copyright 2026 The MathWorks, Inc.

    q = char(34);   % "
    for i = 1:size(pairs, 1)
        from = regexptranslate("escape", string(pairs{i,1}));
        to = regexptranslate("escape", string(pairs{i,2}));
        json = regexprep(json, "([{,]\s*)" + q + from + q + "(\s*):", ...
            "$1" + q + to + q + "$2:");
    end
    json = char(json);
end
