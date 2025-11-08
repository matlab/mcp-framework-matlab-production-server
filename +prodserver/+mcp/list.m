function items = list(endpoint, type)
% List all of the MCP primitives of TYPE available at ENDPOINT.
% Returns a MATLAB structure corresponding to the MCP protocol JSON 
% description of the available primitives, or empty if none exist.
%
% Examples:
%
%    tools = prodsever.mcp.list("http://localhost:9910/cleanSignal/mcp", "Tools")
%    tools =
%        struct with fields:
%                  name: 'cleanSignal'
%           description: 'Removes periodic noise from a signal using ' ...
%           inputSchema: [1x1 struct]
%          outputSchema: [1x1 struct]
%
% See also: prodserver.mcp.Primitive

% Copyright 2025, The MathWorks, Inc.

    arguments
        endpoint string { prodserver.mcp.validation.mustBeMCPServer }
        type (1,1) prodserver.mcp.Primitive 
    end

    %
    % Initialize connection via JSON-RPC "initialize" message.
    %

    % Require that the server publish the resources we're inquiring about.
    try    
        [session,id] = prodserver.mcp.internal.initialize(endpoint, ...
            require=type);

        % Terminate session -- no response expected.
        terminator = onCleanup(@()prodserver.mcp.internal.terminate( ...
            endpoint,session));
        
        % List all primitives of TYPE at ENDPOINT
        items = prodserver.mcp.internal.list(endpoint,session,type,id=id);
        items = items.(lower(string(type)));

    catch me
        if strcmpi(me.identifier,"prodserver:mcp:HttpError") && ...
                contains(me.message, "404: Not Found", IgnoreCase=true)
            error("Unknown MCP server %s.", endpoint);
        end
        items = [];
    end
end
