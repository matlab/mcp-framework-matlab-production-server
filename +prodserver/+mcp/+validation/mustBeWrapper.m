function mustBeWrapper(x)
% mustBeWrapper Error if X is not a wrapper function or a function that
% generates a wrapper function. May be empty or a vector.

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    
    if isempty(x) || (isstring(x) && all(strlength(x) == 0))
        return;
    end

    % Valid types
    validateattributes(x,["function_handle","string","char"], "nonempty");

    for n = 1:numel(x)
        % Because x(1) actually calls x() if x is a function handle. But
        % you can't have vectors of function handles, so they will always
        % be scalars.
        if isscalar(x)
            w = x;
        else
            w = x(n);
        end
        if isstring(w) || ischar(w)
            % Path to an existing MATLAB function file, the text 'None' or a
            % zero-length string.
            if strlength(w) == 0 || strcmpi(w,MCPConstants.NoWrapper)
                return;
            end
            mustBeFile(w);
        else
            % Handle of a function that generates a MATLAB function file.
            % The function must exist.
            f = which(func2str(w));
            if isempty(f)
                error("prodserver:mcp:WrapperGeneratorNotFound", ...
                    "Wrapper generator function %s not found.", func2str(w));
            end
        end
    end
end
