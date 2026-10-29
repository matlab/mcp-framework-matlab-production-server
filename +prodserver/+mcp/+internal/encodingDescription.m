function desc = encodingDescription(desc, encoding)
%encodingDescription A tool's description, with what its encoding needs.
%   desc = encodingDescription(desc, encoding) adds, under the invertible
%   encoding, the sentence telling the LLM to read the wire-encoding
%   resource before calling the tool, unless DESC already names the
%   resource. Under plain JSON the sentence is removed. Both schema paths
%   use this.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    if encoding == prodserver.mcp.WireEncoding.Invertible
        if ~contains(desc, MCPConstants.WireEncodingResourceURI)
            desc = desc + " " + MCPConstants.WireEncodingRequiredMsg;
        end
    else
        desc = erase(desc, " " + MCPConstants.WireEncodingRequiredMsg);
    end
end
