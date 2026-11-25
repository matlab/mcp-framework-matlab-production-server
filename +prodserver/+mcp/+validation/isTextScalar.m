function tf = isTextScalar(v)
%isTextScalar True for one piece of text: a string scalar that is not
%missing, a character row vector, or ''.
%
%   The one text-scalar test of the data plane, so a check and the message
%   that reports it never disagree about what counts as text.
%
%   See also prodserver.mcp.validation.istext

% Copyright 2026 The MathWorks, Inc.

% Contract:
%   Kind:      query
%   Requires:  none
%   Ensures:   tf is false for a missing string, a non-scalar and every non-text type
%   Raises:    none

    tf = (isstring(v) && isscalar(v) && ~ismissing(v)) || ...
        (ischar(v) && (isrow(v) || isequal(size(v), [0 0])));
end
