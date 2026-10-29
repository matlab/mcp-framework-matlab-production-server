function tf = acceptsJson(headers)
%acceptsJson Does a request's Accept header admit an application/json reply?
%   True when there is no Accept header (RFC 9110 §12.5.1: absent means any
%   type is acceptable), or when any listed media range is application/json,
%   application/* or */*. Range parameters -- ";q=0.9", ";charset=utf-8" --
%   are stripped before comparing, so they cannot defeat the match. (A range
%   with q=0 strictly means "not acceptable", but no client sends that for
%   the only type it can read; not worth the parsing.)
%
%   Every Accept header counts, not just the first: a list may be split
%   across repeated fields.
%
%   Never throws. A malformed header list is not this check's to diagnose:
%   it answers true and leaves the rest of the pipeline to report the
%   request.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    tf = true;
    if ~iscell(headers) || isempty(headers) || size(headers,2) ~= 2 || ...
            ~iscellstr(headers(:,1))
        return
    end
    rows = strcmpi(headers(:,1), MCPConstants.Accept);
    if ~any(rows)
        return
    end
    values = headers(rows,2);
    if ~all(cellfun(@(v) (ischar(v) && (isrow(v) || isempty(v))) || ...
            (isstring(v) && isscalar(v)), values))
        return
    end

    ranges = split(join(string(values), ","), ",");
    ranges = prodserver.mcp.internal.mediaType(ranges);
    tf = any(ismember(ranges, [prodserver.mcp.internal.Constants.MIMETypeJSON, "application/*", "*/*"]));
end
