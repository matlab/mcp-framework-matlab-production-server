function caps = capabilities()
%capabilities The capabilities every protocol revision advertises.
%   caps = capabilities() is the dispatcher's capabilities with
%   listChanged false: the lists are fixed by the CTF, and in JSON-only
%   mode the server has no stream to send notifications on.

% Copyright 2026 The MathWorks, Inc.

    caps = prodserver.mcp.handler.ProtocolDispatcher.instance().capabilities();
    fn = fieldnames(caps);
    for i = 1:numel(fn)
        caps.(fn{i}).listChanged = false;
    end
end
