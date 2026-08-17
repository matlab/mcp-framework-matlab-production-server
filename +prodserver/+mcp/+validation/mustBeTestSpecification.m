function mustBeTestSpecification(x)
%mustBeTestSpecification Error if X is not a valid test specification.
%   Accepts: function_handle, cell array (of valid test specs),
%   string/char (file paths, folder paths, or function names on path).

% Copyright 2026 The MathWorks, Inc.

    if isempty(x)
        return;
    end

    if ~isa(x, 'function_handle') && ~iscell(x) && ~isstring(x) && ~ischar(x)
        error("prodserver:mcp:InvalidTestType", ...
            "Test specification must be a function handle, cell array, " + ...
            "or string. Got: %s", class(x));
    end

    if isa(x, 'function_handle')
        return;
    end

    if iscell(x)
        for i = 1:numel(x)
            try
                prodserver.mcp.validation.mustBeTestSpecification(x{i});
            catch ex
                throwAsCaller(MException("prodserver:mcp:InvalidTestSpecification", ...
                    "Cell element %d is not a valid test specification: %s", ...
                    i, ex.message));
            end
        end
        return;
    end

    if isstring(x) || ischar(x)
        x = string(x);
        for i = 1:numel(x)
            t = x(i);
            if isfolder(t)
                continue;
            end
            if exist(t, "file") ~= 0
                continue;
            end
            if exist(t, "builtin") ~= 0
                continue;
            end
            throwAsCaller(MException("prodserver:mcp:TestSpecificationNotFound", ...
                "Test specification '%s' not found as a file, folder, " + ...
                "or function on the MATLAB path.", t));
        end
        return;
    end

    throwAsCaller(MException("prodserver:mcp:InvalidTestSpecification", ...
        "Test specification must be a function handle, cell array, " + ...
        "or string. Got: %s", class(x)));
end
