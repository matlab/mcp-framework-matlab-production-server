function [total, product, report] = schemaComputeNoBlock(x, y, z)
% Compute summary statistics (no argument blocks).

% Copyright 2026 The MathWorks, Inc.

    total = x + y + z;
    product = x * y * z;
    report = sprintf("total=%.2f product=%.2f", total, product);
end
