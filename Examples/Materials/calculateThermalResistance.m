function result = calculateThermalResistance(thickness, area, thermal_conductivity, T_hot, T_cold)
%calculateThermalResistance Steady-state conductive heat transfer through a
%flat plate.
%
% Applies Fourier's law to calculate thermal resistance, heat transfer
% rate and heat flux for one-dimensional steady-state conduction through
% a flat plate of uniform thickness and known thermal conductivity.

% Copyright 2026 The MathWorks, Inc.

    arguments (Input)
        % Plate thickness (meters)
        thickness (1,1) double
        % Cross-sectional area for heat flow (square meters)
        area (1,1) double
        % Material thermal conductivity (W/(m*K)). Read from material resource.
        thermal_conductivity (1,1) double
        % Hot-side boundary temperature (degrees Celsius)
        T_hot (1,1) double
        % Cold-side boundary temperature (degrees Celsius)
        T_cold (1,1) double
    end
    arguments (Output)
        % Struct with fields: thermal_resistance_KperW, heat_transfer_rate_W,
        % heat_flux_Wperm2, midpoint_temperature_C, summary
        result (1,1) struct
    end

    R_thermal = thickness / (thermal_conductivity * area);
    Q = (T_hot - T_cold) / R_thermal;
    q = Q / area;
    T_mid = (T_hot + T_cold) / 2;

    summary = sprintf("Heat flow: %.4g W through %.3g mm plate (%.4g m^2). " + ...
        "Thermal resistance %.4g K/W.", ...
        Q, thickness * 1000, area, R_thermal);

    result.thermal_resistance_KperW = R_thermal;
    result.heat_transfer_rate_W = Q;
    result.heat_flux_Wperm2 = q;
    result.midpoint_temperature_C = T_mid;
    result.summary = summary;
end
