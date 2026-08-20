function encoding = toolEncoding(tool,opts)
% Extract the encoding used by a given tool from the tool signature.

% Copyright 2026 The MathWorks, Inc.

    arguments
        tool 
        opts.sig = [];
        opts.defFile = prodserver.mcp.MCPConstants.DefinitionFile
    end

    import prodserver.mcp.MCPConstants
    if isempty(opts.sig)
        d = load(opts.defFile);
        sig = d.(MCPConstants.DefinitionVariable).signatures;
    else
        sig = opts.sig;
    end
        
    if isfield(sig, tool) && isfield(sig.(tool), 'encoding')
        encoding = prodserver.mcp.WireEncoding(sig.(tool).encoding);
    else
        encoding = prodserver.mcp.WireEncoding.Invertible;
    end
end
