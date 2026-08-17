function [total, product, report] = schemaComputeOutputOnly(x, y, z, opts)
% Compute summary statistics (output argument block only).

% Copyright 2026 The MathWorks, Inc.

    arguments(Output)
        total (1,1) double       % Sum of measurements times scale
        product (1,1) double     % Product of measurements
        report (1,1) string      % Formatted result string
    end

    if nargin < 4, opts = struct(); end
    if ~isfield(opts,'scale'), opts.scale = 1.0; end
    if ~isfield(opts,'label'), opts.label = "default"; end

    total = (x + y + z) * opts.scale;
    product = x * y * z;
    report = sprintf("%s: total=%.2f product=%.2f", opts.label, total, product);
end
