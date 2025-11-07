function mustBeWrapper(x)
% mustBeWrapper Error if X is not a wrapper function or a function that
% generates a wrapper function. May be empty.

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    
    if isempty(x) || (isstring(x) && all(strlength(x) == 0))
        return;
    end

    % Valid types
    validateattributes(x,["function_handle","string","char"], "nonempty");

    if isstring(x) || ischar(x)
        % Path to an existing MATLAB function file, the text 'None' or a
        % zero-length string.
        if strlength(x) == 0 || strcmpi(x,MCPConstants.NoWrapper)
            return;
        end
        mustBeFile(x);
    else
        % Handle of a function that generates a MATLAB function file.
        % The function must exist.
        w = which(func2str(x));
        if isempty(w)
            error("prodserver:mcp:WrapperGeneratorNotFound", ...
                "Wrapper generator function %s not found.", func2str(x));
        end
    end
end
