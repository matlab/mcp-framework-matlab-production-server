function token = sessionToken(declared)
%sessionToken A 2025-06-18 session ID, as initialize would issue it.
%   token = sessionToken() is the Mcp-Session-Id of a client that declared
%   no capabilities. token = sessionToken(declared) is that of a client
%   that declared DECLARED, as jsondecode returns it.
%
%   The server answers any session ID it didn't issue with 404, so a test
%   request that needs a session must carry one of these, not a made-up ID.

% Copyright 2026 The MathWorks, Inc.

    arguments
        declared = struct()
    end
    token = char(prodserver.mcp.protocol.v20250618.encodeSession(declared));
end
