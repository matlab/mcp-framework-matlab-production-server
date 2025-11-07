function mustBeServer(x)
%mustBeServer Argument validation function for arguments that must be
%MATLAB Production Server addresses. 

% Copyright 2025, The MathWorks, Inc.

    % Must be a MATLAB Production Server endpoint.
    
    tf = prodserver.mcp.validation.isserver(x);
    
    if tf == false
        % So the error message prints nicely.
        if isempty(x), x = ""; end
        error("prodserver:mcp:InvalidServerAddress", ...
            "Invalid server address '%s'.",x);
    end
   
end