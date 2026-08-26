function mag = schemaColumnVector(measurements, threshold)
% Count exceedances in a measurement vector.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        measurements (:,1) double  % Time series of sensor readings
        threshold (1,1) double     % Level above which a reading counts
    end
    arguments(Output)
        mag (1,1) double           % Number of exceedances
    end

    mag = sum(measurements > threshold);
end
