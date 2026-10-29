function bytes = base64decode(encoded)
%base64decode Decode a Base64 string to a byte array.
%
%   BYTES = base64decode(ENCODED) returns the uint8 row vector encoded by
%   the standard (RFC 4648) Base64 text ENCODED.
%
%   Every Base64 decode in the framework goes through this function, so a
%   faster implementation only has to replace this file. tBase64 fails if
%   any other framework file calls matlab.net.base64decode directly.

% Copyright 2026 The MathWorks, Inc.

    bytes = reshape(matlab.net.base64decode(encoded), 1, []);
end
