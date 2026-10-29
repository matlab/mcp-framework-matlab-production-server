function decoded = decodeHeaderValue(value)
%decodeHeaderValue Reverse encodeHeaderValue's Base64 header sentinel.
%   A server MUST decode an encoded header value before comparing it to the
%   body, or every non-ASCII resource URI reports a mismatch that is not
%   one. A value carrying no sentinel is returned unchanged, so this is safe
%   to call on every header value rather than only the ones a client chose
%   to encode -- which the server cannot know in advance.
%
%   A malformed payload between the markers is returned verbatim rather than
%   raised on. The caller is a header/body comparison whose only verdict is
%   -32020, and undecodable input will fail that comparison anyway; throwing
%   a decoder error here would surface as -32603/500 instead, reporting a
%   client's bad header as a server fault.

% Copyright 2026 The MathWorks, Inc.

    C = prodserver.mcp.protocol.v20260728.Constants;

    value = string(value);
    decoded = value;

    if ~startsWith(value, C.HeaderSentinelPrefix) || ...
            ~endsWith(value, C.HeaderSentinelSuffix)
        return
    end

    first = strlength(C.HeaderSentinelPrefix) + 1;
    last = strlength(value) - strlength(C.HeaderSentinelSuffix);
    if last < first
        return
    end
    payload = extractBetween(value, first, last);

    try
        bytes = prodserver.mcp.internal.base64decode(payload);
        decoded = string(native2unicode(uint8(bytes(:))', "UTF-8"));
    catch
        decoded = value;
    end
end
