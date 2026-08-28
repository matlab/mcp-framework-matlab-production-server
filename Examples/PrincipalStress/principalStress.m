function sigma = principalStress(stressState, component)
% Compute principal stresses using Mohr's circle.
%
%    sigma = principalStress(stressState, component) computes the principal
%        stress component ("min", "max", "maxShear") in MPa from the 2D
%        stressState [tension, compression, shear].

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        stressState (1,3) double  % 2D stress state [sigma_x, sigma_y, tau_xy] in MPa
        component (1,1) string    % Principal stress component: "max", "min", or "maxShear"
    end
    arguments(Output)
        sigma (1,1) double        % Computed principal stress in MPa
    end

    sx = stressState(1);     % X normal force (sigma x)
    sy = stressState(2);     % Y normal force (sigma y)
    txy = stressState(3);    % Shear stress   (tau xy)

    R = sqrt(((sx - sy) / 2)^2 + txy^2);

    switch component
        case "max"
            sigma = (sx + sy) / 2 + R;   % Maximum principal stress
        case "min"
            sigma = (sx + sy) / 2 - R;   % Minimum principal stress
        case "maxShear"
            sigma = R;                   % Max. in-plane shear stress
    end
end
