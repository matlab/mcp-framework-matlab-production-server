function [r, t] = schemaDataFields(n)
% Return structs whose fields look like parts of the invertible wrapper.
%   n - A count
%   r - A struct with a data field
%   t - A struct with type and data fields

% Copyright 2026 The MathWorks, Inc.

    r.data = 1:n;
    r.units = "m";
    t.type = "reading";
    t.data = 1:n;
end
