function mustBeMCPServer(x)
%mustBeMCPServer Argument validation function for arguments that must be
%Model Context Protocol Server addresses. 

% Copyright 2025, The MathWorks, Inc.

    % Must be a Model Context Protocol Server endpoint.
    
	mustBeTextScalar(x);
    tf = prodserver.mcp.validation.isMCPserver(x);
    
    if tf == false
        % So the error message prints nicely.
        if isempty(x), x = ""; end
        error("prodserver:mcp:InvalidServerAddress", ...
            "Invalid MCP server address '%s'.",x);
    end
   
end