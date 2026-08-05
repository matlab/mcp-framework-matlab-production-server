function result = analyzeBeam(beam_spec, load_case)
% Analyze a simply-supported beam under load. Computes maximum bending
% stress, maximum deflection and first natural frequency given the beam
% geometry, material properties and applied load. Supports rectangular and
% circular cross-sections with point or uniformly distributed loads.

% Copyright 2026 The MathWorks, Inc.

    arguments (Input)
        % Beam specification: material properties, cross-section geometry and span length.
        %#schema =beam_spec.json
        beam_spec (1,:) struct

        % Applied load: type (point or distributed), magnitude and position.
        %#schema =load_case.json
        load_case (1,:) struct
    end
    arguments (Output)
        % Analysis results: max_stress_Pa, max_deflection_m, natural_frequency_Hz,
        % second_moment_of_area_m4, cross_section_area_m2 and summary.
        result (1,1) struct
    end

    E = beam_spec.material.youngs_modulus;
    rho = beam_spec.material.density;
    L = beam_spec.length;

    switch lower(beam_spec.cross_section.shape)
        case "rectangular"
            w = beam_spec.cross_section.width;
            h = beam_spec.cross_section.height;
            I = (w * h^3) / 12;
            A = w * h;
            y_max = h / 2;
        case "circular"
            d = beam_spec.cross_section.diameter;
            I = pi * d^4 / 64;
            A = pi * d^2 / 4;
            y_max = d / 2;
        otherwise
            error("analyzeBeam:UnsupportedCrossSection", ...
                "Cross-section type '%s' not supported. Use rectangular or circular.", ...
                beam_spec.cross_section.shape);
    end

    switch lower(load_case.type)
        case "point"
            a = load_case.position;
            b = L - a;
            P = load_case.magnitude;
            M_max = (P * a * b) / L;
            delta_max = (P * L^3) / (48 * E * I);
        case "distributed"
            w_load = load_case.magnitude;
            M_max = (w_load * L^2) / 8;
            delta_max = (5 * w_load * L^4) / (384 * E * I);
        otherwise
            error("analyzeBeam:UnsupportedLoadType", ...
                "Load type '%s' not supported. Use point or distributed.", ...
                load_case.type);
    end

    sigma_max = (M_max * y_max) / I;
    f1 = (pi / (2 * L^2)) * sqrt((E * I) / (rho * A));

    summary = sprintf( ...
        "Max stress %.4g MPa, max deflection %.4g mm, " + ...
        "natural frequency %.4g Hz.", ...
        sigma_max / 1e6, delta_max * 1000, f1);

    result.max_stress_Pa = sigma_max;
    result.max_deflection_m = delta_max;
    result.natural_frequency_Hz = f1;
    result.second_moment_of_area_m4 = I;
    result.cross_section_area_m2 = A;
    result.summary = summary;
end
