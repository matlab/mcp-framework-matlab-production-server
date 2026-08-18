function [total, product, report] = schemaCompute(x, y, z, opts)
% Compute summary statistics from three measurements.
%
% Demonstrates a realistic function with positional inputs, NVP options,
% and multiple typed outputs.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        x (1,1) double           % First measurement
        y (1,1) double           % Second measurement
        z (1,1) double           % Third measurement
        opts.scale (1,1) double = 1.0   % Scaling factor
        opts.label (1,1) string = "default"  % Result label
    end

    arguments(Output)
        total (1,1) double       % Sum of measurements times scale
        product (1,1) double     % Product of measurements
        report (1,1) string      % Formatted result string
    end

    total = (x + y + z) * opts.scale;
    product = x * y * z;
    report = sprintf("%s: total=%.2f product=%.2f", opts.label, total, product);
end
