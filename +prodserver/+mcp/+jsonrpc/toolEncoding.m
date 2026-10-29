function encoding = toolEncoding(tool,opts)
% Extract the encoding used by a given tool from the tool signature.
%   encoding = toolEncoding(tool, sig=sig) is the encoding the signature
%   records. A signature without one (from an older build) is JSON, unless
%   def=definition is given and its description names the wire-encoding
%   resource, which only an invertibly encoded tool's does. The server,
%   and the client for both its inputs and outputs, decide it here.

% Copyright 2026 The MathWorks, Inc.

    arguments
        tool 
        opts.sig = [];
        opts.defFile = prodserver.mcp.MCPConstants.DefinitionFile
        opts.def = []
    end

    import prodserver.mcp.MCPConstants
    if isempty(opts.sig)
        d = load(opts.defFile);
        sig = d.(MCPConstants.DefinitionVariable).signatures;
    else
        sig = opts.sig;
    end
        
    import prodserver.mcp.internal.hasField
    if hasField(sig, string(tool) + ".encoding")
        encoding = prodserver.mcp.WireEncoding(sig.(tool).encoding);
    elseif hasField(opts.def, "description") && ...
            contains(string(opts.def.description), MCPConstants.WireEncodingResourceURI)
        encoding = prodserver.mcp.WireEncoding.Invertible;
    else
        encoding = prodserver.mcp.WireEncoding.JSON;
    end
end
