function encoded = base64encode(bytes)
%base64encode Base64-encode a byte array.
%
%   ENCODED = base64encode(BYTES) returns the standard (RFC 4648) Base64
%   encoding of the uint8 array BYTES as a char row vector.
%
%   Every Base64 encode in the framework goes through this function, so a
%   faster implementation only has to replace this file. tBase64 fails if
%   any other framework file calls matlab.net.base64encode directly.

% Copyright 2026 The MathWorks, Inc.

    encoded = matlab.net.base64encode(uint8(bytes(:))');
end
