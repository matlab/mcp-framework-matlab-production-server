function tf = exist(endpoint, identifier, type, opts)
%exist Check existence of tools, resources and prompts on the given server.
%
%   tf = exist(endpoint, identifier, type) returns TRUE if IDENTIFIER
%       exists as a TYPE on the MCP server at ENDPOINT. For tools,
%       IDENTIFIER is the tool name. For resources, IDENTIFIER is the
%       resource URI. IDENTIFIER may be a list. TYPE must be a scalar.
%
% See also: prodserver.mcp.Primitive

% Copyright 2025-2026 The MathWorks, Inc.


    arguments
        endpoint string { prodserver.mcp.validation.mustBeMCPServer }
        identifier string { mustBeTextScalar }
        type prodserver.mcp.Primitive { prodserver.mcp.validation.mustBeSameSize(2,identifier,type) }
        opts.timeout double {mustBePositive} = 30
        opts.retry double {mustBePositive} = 10
        opts.delay double {mustBePositive} = 2
    end

    import prodserver.mcp.internal.hasField

    tf = false(size(identifier));

    %
    % Initialize connection via JSON-RPC "initialize" message.
    %

    % Require that the server publish the resources we're inquiring about.
    [session,id] = prodserver.mcp.internal.initialize(endpoint, ...
        require=type, timeout=opts.timeout, retry=opts.retry, ...
        delay=opts.delay);

    %
    % Check TYPE, to verify that IDENTIFIER exists at ENDPOINT
    %

    % Get a list of all the elements of each requested primitive type
    items = prodserver.mcp.internal.list(endpoint,session, ...
        type,id=id,timeout=opts.timeout, retry=opts.retry, ...
        delay=opts.delay);

        for n = 1:numel(items)
    
            % Name of the primitive type's field in items
            t = mcpName(type(n));
            p = items.(t);

            % Resources are identified by URI; other primitives by name.
            if type(n) == prodserver.mcp.Primitive.Resource
                field = "uri";
            else
                field = "name";
            end

            % Out, out, damn char!
            if iscell(p)
                ids = cellfun(@(r)string(r.(field)),p);
            elseif isstruct(p)
                if isempty(p) == false
                    ids = string({p.(field)});
                else
                    ids = {};
                end
            end

            % If we find exactly one primitive with the requested
            % identifier, the primitive "exists".
            found = strcmp(identifier(n),ids);
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
