function [sid, caps, ok] = decodeSession(id)
%decodeSession Recover the client's capabilities from a session ID.
%   [sid, caps, ok] = decodeSession(id) reads a session ID that
%   encodeSession issued. SID is the session's UUID, CAPS a
%   ClientCapabilities, and OK true.
%
%   Any other ID is unreadable: OK is false, SID is "" and CAPS is
%   ClientCapabilities.none(). That includes plain UUIDs, which this server
%   issued before session IDs carried capabilities, and any ID longer than
%   Constants.SessionTokenMaxLength, since encodeSession never issues one.
%   The client's data isn't trusted to be well formed, so nothing here
%   raises an error.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.protocol.v20250618.Constants
    import prodserver.mcp.protocol.ClientCapabilities

    sid = "";
    caps = ClientCapabilities.none();
    ok = false;

    if ~prodserver.mcp.validation.istext(id)
        return
    end
    id = string(id);
    if ~isscalar(id) || ismissing(id) || ...
            strlength(id) > Constants.SessionTokenMaxLength || ...
            ~startsWith(id, Constants.SessionTokenPrefix)
        return
    end

    try
        bytes = prodserver.mcp.internal.base64decode( ...
            extractAfter(id, strlength(Constants.SessionTokenPrefix)), ...
            URLSafe=true);
        payload = jsondecode(native2unicode(bytes, "UTF-8"));
    catch
        return
    end

    % One piece of text: a JSON array of strings decodes to a cellstr,
    % which istext accepts, and would make the tests below non-scalar.
    if ~isstruct(payload) || ~isscalar(payload) || ...
            ~isfield(payload, "sid") || ~isfield(payload, "caps") || ...
            ~prodserver.mcp.validation.isTextScalar(payload.sid) || ...
            strlength(payload.sid) == 0
        return
    end

    try
        caps = ClientCapabilities(payload.caps);
    catch
        caps = ClientCapabilities.none();
        return
    end
    sid = string(payload.sid);
    ok = true;
end
