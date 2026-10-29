function y = schemaValidated(a, b, c, d)
% Combine values whose classes only their validators constrain.

% Copyright 2026 The MathWorks, Inc.

    arguments
        a (1,:) {mustBeNumeric}             % Numbers
        b (1,:) {mustBeText, mustBeNonempty} % Text
        c (1,:) {mustBeFloat, mustBePositive} % Positive floats
        d (1,:)                             % Anything
    end
    arguments (Output)
        y (1,1) double                      % A count
    end
    y = numel(a) + numel(b) + numel(c) + numel(d);
end
