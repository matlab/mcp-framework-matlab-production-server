function mustBeFileOrEmpty(x)
%mustBeFileOrEmpty Validate that each element of x is an existing file, or
%that x is empty. A zero-length string counts as empty; a missing string
%is an error. A folder is not a file.

% Copyright 2026 The MathWorks, Inc.

    x = string(x);
    for n = 1:numel(x)
        if ismissing(x(n))
            throwAsCaller(MException("prodserver:mcp:FileNotFound", ...
                "File not found: the file name is missing."));
        end
        if strlength(x(n)) == 0
            continue
        end
        if isfolder(x(n))
            throwAsCaller(MException("prodserver:mcp:NotAFile", ...
                "'%s' is a folder, not a file.", x(n)));
        end
        if ~isfile(x(n))
            throwAsCaller(MException("prodserver:mcp:FileNotFound", ...
                "File not found: '%s'.", x(n)));
        end
    end
end
