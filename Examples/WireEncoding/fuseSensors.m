function [fused, weights, uncertainty] = fuseSensors(sensor1, sensor2)
% Fuse two sensor readings using precision-weighted optimal combination.
%
% Each sensor's quantization noise is derived from its numeric type:
%   uint8  -> 8-bit ADC,  noise = 1/(2*255)    ~ 0.2%
%   uint16 -> 16-bit ADC, noise = 1/(2*65535)  ~ 0.0008%
%   double -> analog/float, noise ~ eps         ~ 0%
%
% Both sensors are normalized to [0,1] using their own range before
% fusion, so the result is meaningful even when the sensors measure in
% different physical units (e.g., meters vs millimeters).
%
% Without wire encoding, JSON numbers have no type annotation. Both
% sensors arrive as double, making the quantization noise eps for both.
% The result is an equal 50/50 blend regardless of actual sensor
% resolution.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        sensor1 {mustBeNumeric}   % Readings from sensor 1 (type = resolution)
        sensor2 {mustBeNumeric}   % Readings from sensor 2 (type = resolution)
    end
    arguments(Output)
        fused (1,:) double        % Optimally fused result (normalized 0-1)
        weights (1,2) double      % Fusion weights [w1, w2]
        uncertainty (1,1) double  % Combined measurement uncertainty
    end

    [s1_norm, q1] = normalizeToUnit(sensor1);
    [s2_norm, q2] = normalizeToUnit(sensor2);

    w1 = q2^2 / (q1^2 + q2^2);
    w2 = q1^2 / (q1^2 + q2^2);

    fused = w1 * s1_norm + w2 * s2_norm;
    weights = [w1, w2];
    uncertainty = sqrt(1 / (1/q1^2 + 1/q2^2));

end

function [normalized, quantization_noise] = normalizeToUnit(data)
    d = double(data);
    lo = min(d);
    hi = max(d);
    range = hi - lo;
    if range == 0
        normalized = 0.5 * ones(size(d));
    else
        normalized = (d - lo) / range;
    end
    switch class(data)
        case 'double'
            quantization_noise = eps;
        otherwise
            quantization_noise = 0.5 / double(intmax(class(data)));
    end
end
