function sigma = schemaFixedVector(stressState, component)
% Compute principal stress from a 2D stress state.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        stressState (1,3) double   % Stress state [tension, compression, shear] in MPa
        component (1,1) string     % Component: "min", "max", or "maxShear"
    end
    arguments(Output)
        sigma (1,1) double         % Principal stress in MPa
    end

    sx = stressState(1);
    sy = stressState(2);
    txy = stressState(3);
    R = sqrt(((sx - sy) / 2)^2 + txy^2);

    switch component
        case "max"
            sigma = (sx + sy) / 2 + R;
        case "min"
            sigma = (sx + sy) / 2 - R;
        case "maxShear"
            sigma = R;
    end
end
