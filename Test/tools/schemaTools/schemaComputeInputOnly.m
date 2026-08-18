function [total, product, report] = schemaComputeInputOnly(x, y, z, opts)
% Compute summary statistics (input argument block only).

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        x (1,1) double           % First measurement
        y (1,1) double           % Second measurement
        z (1,1) double           % Third measurement
        opts.scale (1,1) double = 1.0   % Scaling factor
        opts.label (1,1) string = "default"  % Result label
    end

    total = (x + y + z) * opts.scale;
    product = x * y * z;
    report = sprintf("%s: total=%.2f product=%.2f", opts.label, total, product);
end
