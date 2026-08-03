function tf = isExternalized(param)
% isExternalized True if param was externalized in a function wrapper.
% 
% param is a parameter description structure (see mcpDefintion).

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    tf = false(size(param));
    if isfield(param,"description")
        tf = arrayfun(...
            @(p)startsWith(p.description,MCPConstants.ByReferencePrefix), ...
            param);
    end

end
