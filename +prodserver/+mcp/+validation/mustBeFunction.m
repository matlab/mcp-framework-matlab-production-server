function mustBeFunction(x)
%mustBeFunction Argument validation function for arguments that must be
%functions. 

% Copyright 2025, The MathWorks, Inc.

    % Must be a function that exists.
    tf = prodserver.mcp.validation.isfcn(x, true);
    if all(tf) == false
        % First non-function
        nope = find(~tf); nope = nope(1);
        if isa(x,"function_handle")
            x = string(func2str(x));
        end
        error("prodserver:mcp:FunctionNotFound", ...
           "Cannot find function '%s'.",x(nope));
    end
end
