function result = calculateBeamStress(load, length, width, height, youngs_modulus, yield_strength)
%calculateBeamStress Maximum bending stress, deflection and safety factor
%for a simply-supported rectangular beam under a central point load.
%
% Applies Euler-Bernoulli beam theory to calculate the maximum stress and
% deflection at the midspan of a simply-supported beam with a rectangular
% cross-section subjected to a concentrated load at its center.

% Copyright 2026 The MathWorks, Inc.

    arguments (Input)
        % Applied force at beam center (Newtons)
        load (1,1) double
        % Beam span (meters)
        length (1,1) double
        % Cross-section width (meters)
        width (1,1) double
        % Cross-section height (meters)
        height (1,1) double
        % Material Young's modulus (Pascals). Read from material resource.
        youngs_modulus (1,1) double
        % Material yield strength (Pascals). Read from material resource.
        yield_strength (1,1) double
    end
    arguments (Output)
        % Struct with fields: max_stress_Pa, max_deflection_m,
        % safety_factor, status, summary
        result (1,1) struct
    end

    I = (width * height^3) / 12;
    M_max = (load * length) / 4;
    sigma_max = (M_max * (height / 2)) / I;
    delta_max = (load * length^3) / (48 * youngs_modulus * I);
    safety_factor = yield_strength / sigma_max;

    if safety_factor >= 1.0
        status = "PASS";
    else
        status = "FAIL";
    end

    summary = sprintf("Beam stress %.3g MPa (yield %.3g MPa, SF=%.2f). " + ...
        "Max deflection %.3g mm.", ...
        sigma_max / 1e6, yield_strength / 1e6, safety_factor, delta_max * 1000);

    result.max_stress_Pa = sigma_max;
    result.max_deflection_m = delta_max;
    result.safety_factor = safety_factor;
    result.status = status;
    result.summary = summary;
end
