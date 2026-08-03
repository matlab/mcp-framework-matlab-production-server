function parameters = explainWireEncoding(parameters,io,external)
% Add the wire encoding reference to the description of each parameter.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    
    % For every parameter...
    param = keys(parameters)';
    
    if strcmpi(io,"input")
        wireEncodingMsg = MCPConstants.WireEncodingInputMsg;
    else
        wireEncodingMsg = MCPConstants.WireEncodingOutputMsg;
    end
    
    for p = param
        % Don't add encoding comment to externalized parameters.
        if nnz(ismember(p,external)) == 0 && ...
                ~any(contains(parameters(p).description, MCPConstants.ByReferencePrefix))
            % And don't add it twice.
            alreadyExplained = contains(parameters(p).description,...
                MCPConstants.WireEncodingResourceURI);
    
            if nnz(alreadyExplained) == 0
                parameters(p).description = [ parameters(p).description; ...
                    wireEncodingMsg ];
            end
        end
    end
end