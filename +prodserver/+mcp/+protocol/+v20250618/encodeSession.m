function token = encodeSession(declared)
%encodeSession A session ID that carries the client's capabilities.
%   token = encodeSession(declared) returns the Mcp-Session-Id that
%   initialize issues to a client that declared the capabilities DECLARED,
%   as jsondecode returned them.
%
%   2025-06-18 clients declare their capabilities once, in initialize, and
%   send the session ID back, unchanged, with every later request. The
%   server keeps no session state, and any worker may serve any request, so
%   the capabilities travel in the session ID: decodeSession recovers them.
%
%   The token is v1. followed by the URL-safe Base64 of the JSON
%   {"sid": <a new UUID>, "caps": <DECLARED>}: visible ASCII, as the
%   protocol requires. The UUID keeps the ID unique and unguessable, and is
%   the part to use as a key, never the whole token.
%
%   It is never longer than Constants.SessionTokenMaxLength. If the full
%   declaration would make it longer, the token keeps only the names of the
%   declared capabilities and extensions, without their settings; if even
%   that is too long, only the extensions the framework uses.

% Copyright 2026 The MathWorks, Inc.

    arguments
        declared = struct()
    end

    import prodserver.mcp.protocol.v20250618.Constants

    if ~isstruct(declared) || ~isscalar(declared)
        declared = struct();
    end
    sid = string(matlab.lang.internal.uuid);

    candidates = {declared, namesOnly(declared), frameworkOnly(declared)};
    for n = 1:numel(candidates)
        token = makeToken(sid, candidates{n});
        if strlength(token) <= Constants.SessionTokenMaxLength
            return
        end
    end
    token = makeToken(sid, struct());
end

function token = makeToken(sid, caps)
    import prodserver.mcp.protocol.v20250618.Constants
    json = jsonencode(struct("sid", sid, "caps", caps));
    token = Constants.SessionTokenPrefix + string( ...
        prodserver.mcp.internal.base64encode(unicode2native(json, "UTF-8"), ...
            URLSafe=true));
end

function caps = namesOnly(declared)
% Each declared capability and extension, without its settings.
    caps = struct();
    names = string(fieldnames(declared));
    for n = 1:numel(names)
        if names(n) == "extensions" && isstruct(declared.extensions) && ...
                isscalar(declared.extensions)
            caps.extensions = struct();
            ids = string(fieldnames(declared.extensions));
            for k = 1:numel(ids)
                caps.extensions.(ids(k)) = struct();
            end
        else
            caps.(names(n)) = struct();
        end
    end
end

function caps = frameworkOnly(declared)
% Only the extensions the framework uses, without their settings.
    caps = struct();
    used = matlab.lang.makeValidName(prodserver.mcp.MCPConstants.UIExtension_JSON);
    if isfield(declared, "extensions") && isstruct(declared.extensions) && ...
            isscalar(declared.extensions) && isfield(declared.extensions, used)
        caps.extensions.(used) = struct();
    end
end
