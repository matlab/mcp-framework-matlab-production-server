function encoded = encodeHeaderValue(value)
%encodeHeaderValue Apply this revision's Base64 header sentinel if needed.
%   Returns VALUE unchanged when it can travel as a plain HTTP header value,
%   and "=?base64?<b64>?=" when it cannot. The client MUST do this to any
%   Mcp-Name it sends; decodeHeaderValue is the inverse the server MUST
%   apply before comparing.
%
%   Encoded when the value:
%     - contains a non-ASCII character (an MCP resource URI may hold any
%       Unicode, an HTTP header field value may not);
%     - contains a control character, which includes the CR and LF that
%       would otherwise split the header or the message;
%     - has leading or trailing whitespace, which a conforming HTTP
%       intermediary is free to strip, silently changing the value;
%     - already looks like a sentinel. Encoding it again is what keeps the
%       round trip unambiguous: without this, a resource literally named
%       "=?base64?Zm9v?=" would decode to "foo" at the far end.
%
%   The markers are lowercase and case-sensitive, per the spec, so they live
%   in Constants rather than being typed at each end.
%
%   Base64 covers UTF-8 bytes, not UTF-16 code units: a header value is a
%   byte string, so the value is converted to UTF-8 first and converted back
%   on the far side. Skipping that step round-trips correctly for ASCII and
%   corrupts exactly the characters this function exists for.

% Copyright 2026 The MathWorks, Inc.

    C = prodserver.mcp.protocol.v20260728.Constants;

    value = string(value);
    encoded = value;
    if strlength(value) == 0
        return
    end

    if ~needsEncoding(value, C)
        return
    end

    bytes = unicode2native(char(value), "UTF-8");
    encoded = C.HeaderSentinelPrefix + ...
        string(prodserver.mcp.internal.base64encode(bytes)) + C.HeaderSentinelSuffix;
end

function tf = needsEncoding(value, C)
    codes = double(char(value));
    tf = any(codes > 126) || any(codes < 32) || ...
         ~strcmp(char(value), char(strtrim(value))) || ...
         (startsWith(value, C.HeaderSentinelPrefix) && ...
          endsWith(value, C.HeaderSentinelSuffix));
end
