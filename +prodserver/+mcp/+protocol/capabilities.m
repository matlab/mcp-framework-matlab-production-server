function caps = capabilities()
%capabilities The capabilities every protocol revision advertises.
%   caps = capabilities() is the dispatcher's capabilities with
%   listChanged false: the lists are fixed by the CTF, and in JSON-only
%   mode the server has no stream to send notifications on.
%
%   An archive built with an MCP App also advertises the MCP Apps UI
%   extension, io.modelcontextprotocol/ui, under extensions. The field is
%   MCPConstants.UIExtension_Field here; the protocol adapter renames it to
%   the wire name for every revision (see Adapter.SharedFieldNames).

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    caps = prodserver.mcp.handler.ProtocolDispatcher.instance().capabilities();
    fn = fieldnames(caps);
    for i = 1:numel(fn)
        caps.(fn{i}).listChanged = false;
    end

    % The definition file records whether the archive has an app. A server
    % whose definitions can't be loaded advertises no extension, rather
    % than failing initialize or server/discover.
    try
        svc = prodserver.mcp.handler.toolServices;
    catch
        svc = [];
    end
    if ~isempty(svc) && isfield(svc, MCPConstants.AppResourceVariable)
        caps.extensions.(MCPConstants.UIExtension_Field) = struct();
    end
end
