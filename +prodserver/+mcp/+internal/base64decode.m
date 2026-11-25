function bytes = base64decode(encoded, opts)
%base64decode Decode a Base64 string to a byte array.
%
%   BYTES = base64decode(ENCODED) returns the uint8 row vector encoded by
%   the standard (RFC 4648) Base64 text ENCODED.
%
%   BYTES = base64decode(ENCODED, URLSafe=true) decodes the URL- and
%   filename-safe variant (RFC 4648 section 5), with or without padding.
%   Characters outside that alphabet are an error,
%   prodserver:mcp:InvalidBase64URL, rather than being skipped as the
%   standard decoder skips them.
%
%   Every Base64 decode in the framework goes through this function, so a
%   faster implementation only has to replace this file. tBase64 fails if
%   any other framework file calls matlab.net.base64decode directly.

% Copyright 2026 The MathWorks, Inc.

    arguments
        encoded
        opts.URLSafe (1,1) logical = false
    end

    if opts.URLSafe
        encoded = char(encoded);
        % ASCII only: isstrprop's alphanum also accepts letters like é.
        ok = (encoded >= 'A' & encoded <= 'Z') | (encoded >= 'a' & encoded <= 'z') | ...
            (encoded >= '0' & encoded <= '9') | encoded == '-' | encoded == '_' | ...
            encoded == '=';
        if ~all(ok)
            error("prodserver:mcp:InvalidBase64URL", ...
                "Not URL-safe Base64: it contains characters outside A-Z, " + ...
                "a-z, 0-9, - and _.");
        end
        encoded = strrep(strrep(encoded, '-', '+'), '_', '/');
        encoded = [encoded, repmat('=', 1, mod(-numel(encoded), 4))];
    end
    bytes = reshape(matlab.net.base64decode(encoded), 1, []);
end
