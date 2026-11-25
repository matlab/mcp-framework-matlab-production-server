function value = requestHeader(request, name)
%requestHeader The value of a request header, matched ignoring case; []
%   when the request has no such header, or no headers.
%
%   The guard matters as much as the read. Headers arrive as an Nx2 cell
%   array, and getHeaderValue rejects one that is not two columns wide --
%   which an empty {} is not -- so every caller that might see a request
%   with no headers has to check first. Hand-rolled copies of that guard
%   were the only thing standing between a header-less request and an
%   error about name-value pairs.
%
%   See also prodserver.mcp.internal.getHeaderValue

% Copyright 2026 The MathWorks, Inc.

% Contract:
%   Kind:      query
%   Requires:  none (request may lack Headers, or have an empty one)
%   Ensures:   value is the first NAME header's value, or [] when there is none
%   Raises:    prodserver:mcp:InvalidHeaderList, for a non-empty Headers that is not Nx2

    value = [];
    if ~isstruct(request) || ~isscalar(request) || ~isfield(request, 'Headers') || ...
            isempty(request.Headers)
        return
    end
    value = prodserver.mcp.internal.getHeaderValue(name, request.Headers);
end
