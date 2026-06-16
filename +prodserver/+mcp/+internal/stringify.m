function s = stringify(s)
%stringify Turn every char vector (the 1970s called, they want their
%datatype back) in s into a string.

% Copyright 2023 The MathWorks, Inc.

    % Know thyself in order to recurse.
    import prodserver.mcp.internal.stringify
    import prodserver.mcp.internal.apply

    s = apply(@char2string, s, Recurse=true);

    % Find cell arrays of strings and convert them to string arrays
    s = apply(@cell2string, s, Recurse=true, Skip=@iscelltext);
end

function tf = iscelltext(s)
    tf = false;
    if iscell(s)
        isText = cellfun(@(s)ischar(s) || isstring(s),s);
        tf = all(isText);
    end
end

function s = cell2string(s)
    if iscell(s)
        isText = cellfun(@(s)ischar(s) || isstring(s),s);
        if all(isText)
            s = string(s);
        end
    end
end

function s = char2string(s)
    if ischar(s)
        s = string(s);
    end
end

