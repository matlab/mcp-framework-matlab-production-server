function encoded = base64encode(bytes, opts)
%base64encode Base64-encode a byte array.
%
%   ENCODED = base64encode(BYTES) returns the standard (RFC 4648) Base64
%   encoding of the uint8 array BYTES as a char row vector.
%
%   ENCODED = base64encode(BYTES, URLSafe=true) returns the URL- and
%   filename-safe variant (RFC 4648 section 5) without padding: - and _ in
%   place of + and /, and no trailing =.
%
%   Every Base64 encode in the framework goes through this function, so a
%   faster implementation only has to replace this file. tBase64 fails if
%   any other framework file calls matlab.net.base64encode directly.

% Copyright 2026 The MathWorks, Inc.

    arguments
        bytes
        opts.URLSafe (1,1) logical = false
    end

    encoded = matlab.net.base64encode(uint8(bytes(:))');
    if opts.URLSafe
        encoded = strrep(strrep(encoded, '+', '-'), '/', '_');
        encoded = encoded(1:find(encoded ~= '=', 1, 'last'));
    end
end
