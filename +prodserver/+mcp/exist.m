function tf = exist(endpoint, name, type)
%exist Check existence of tools, resources and prompts on the given server.
%
%   tf = exist(endpoint, name, type) returns TRUE if NAME exists as a TYPE
%       on the MCP server at ENDPOINT. NAME may be a list of names. TYPE
%       must be a scalar.
%    
% See also: prodserver.mcp.Primitive

% Copyright 2025, The MathWorks, Inc.


    arguments
        endpoint string { prodserver.mcp.validation.mustBeMCPServer }
        name string { mustBeTextScalar }
        type prodserver.mcp.Primitive { prodserver.mcp.validation.mustBeSameSize(2,name,type) }
    end

    import prodserver.mcp.internal.hasField

    tf = false(size(name));

    %
    % Initialize connection via JSON-RPC "initialize" message.
    %

    % Require that the server publish the resources we're inquiring about.
    [session,id] = prodserver.mcp.internal.initialize(endpoint, require=type);

    %
    % Check TYPE, to verify that NAME exists at ENDPOINT
    %

    % Get a list of all the elements of each requested primitive type
    items = prodserver.mcp.internal.list(endpoint,session, ...
        type,id=id);

        for n = 1:numel(items)
    
            % Name of the primitive type's field in items
            t = lower(string(type(n)));
            p = items.(t);
    
            % Names of all the <type> primitives on the server.
    
            % Out, out, damn char!
            names = arrayfun(@(r)string(r.name),p);
        
            % If we find exactly one primitive with the requested name,
            % the primitive "exists".
            found = strcmp(name,names);
            if nnz(found) == 1
                tf(n) = true;
            end
        end

    %
    % Terminate session
    %

    % No response expected.
    prodserver.mcp.internal.terminate(endpoint,session);

end
