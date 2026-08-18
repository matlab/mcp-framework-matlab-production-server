function [magnitude, normalized, count] = schemaVectorNoBlock(values, scale)
% Compute vector magnitude, normalize, and count elements.

% Copyright 2026 The MathWorks, Inc.

    if nargin < 2, scale = 1.0; end
    magnitude = norm(values) * scale;
    normalized = values / norm(values);
    count = numel(values);
end
