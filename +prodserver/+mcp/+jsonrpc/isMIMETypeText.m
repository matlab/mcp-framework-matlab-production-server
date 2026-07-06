function tf = isMIMETypeText(mimeType)
%isMIMETypeText Return true when a MIME type denotes human-readable text.
%
%   TF = isMIMETypeText(MIMETYPE) returns logical true when MIMETYPE is
%   considered human-readable and false otherwise.  MIMETYPE may be a
%   char vector or scalar string; the parameters portion (everything after
%   the first semicolon, e.g. "; charset=utf-8") is ignored.
%
%   Rules applied in order:
%     1. Any type whose primary type is "text" is readable
%        (text/plain, text/html, text/csv, text/xml, ...).
%     2. Specific well-known application/* subtypes that carry plain text
%        or a text-based serialisation format.
%     3. Structured subtypes ending in "+json" or "+xml" are readable
%        (application/ld+json, application/atom+xml, ...).
%     4. Everything else (image/*, audio/*, application/octet-stream, ...)
%        is treated as binary.
%
%   Examples:
%     isMIMETypeText("text/plain")                  % true
%     isMIMETypeText("text/html")                   % true
%     isMIMETypeText("application/json")            % true
%     isMIMETypeText("application/ld+json")         % true
%     isMIMETypeText("application/atom+xml")        % true
%     isMIMETypeText("application/octet-stream")    % false
%     isMIMETypeText("image/png")                   % false

% Copyright 2025-2026, The MathWorks, Inc.

    % Strip parameters ("; charset=utf-8", etc.) and normalise case.
    mimeType = lower(strtrim(string(mimeType)));
    mimeType = extractBefore(mimeType + ";", ";");   % guaranteed to find ";"

    % Split into primary type and subtype.
    parts = split(mimeType, "/");
    if numel(parts) ~= 2 || strlength(parts(1)) == 0 || strlength(parts(2)) == 0
        tf = false;
        return
    end
    primaryType = parts(1);
    subtype     = parts(2);

    % Rule 1: all text/* types are human-readable.
    if primaryType == "text"
        tf = true;
        return
    end

    % Rules 2 and 3 apply only within the application/* primary type.
    if primaryType ~= "application"
        tf = false;
        return
    end

    % Rule 2: known text-based application subtypes.
    textSubtypes = [ ...
        "json", ...
        "xml", ...
        "javascript", ...
        "ecmascript", ...
        "yaml", ...
        "x-yaml", ...
        "toml", ...
        "graphql", ...
        "sparql-query", ...
        "sparql-update", ...
        "x-www-form-urlencoded" ...
    ];
    if any(subtype == textSubtypes)
        tf = true;
        return
    end

    % Rule 3: structured subtypes using a text-based encoding.
    if endsWith(subtype, "+json") || endsWith(subtype, "+xml") || ...
            endsWith(subtype, "+yaml")
        tf = true;
        return
    end

    tf = false;
end
