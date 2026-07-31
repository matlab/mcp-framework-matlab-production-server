classdef tMaterialsCalculations < matlab.unittest.TestCase
% Unit tests for calculateBeamStress and calculateThermalResistance.

% Copyright 2026 The MathWorks, Inc.

    methods (TestClassSetup)

        function addExampleToPath(test)
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            exampleFolder = fullfile(testFolder, "..", "..", "..", ...
                "Examples", "Materials");
            test.applyFixture(PathFixture(exampleFolder));
        end

    end

    methods (Test)

        function beamStressKnownValues(test)
            % Simply-supported beam, point load at center.
            % Geometry: L=2m, w=0.05m, h=0.1m
            % Material: E=68.9 GPa, sigma_y=276 MPa
            % Load: 10 kN

            F = 10000;
            L = 2.0;
            w = 0.05;
            h = 0.1;
            E = 68.9e9;
            sigma_y = 276e6;

            result = calculateBeamStress(F, L, w, h, E, sigma_y);

            % Expected values (hand-calculated)
            I = (w * h^3) / 12;
            M_max = (F * L) / 4;
            expected_stress = (M_max * (h/2)) / I;
            expected_deflection = (F * L^3) / (48 * E * I);
            expected_sf = sigma_y / expected_stress;

            test.verifyEqual(result.max_stress_Pa, expected_stress, ...
                "max_stress_Pa", AbsTol=1e-6);
            test.verifyEqual(result.max_deflection_m, expected_deflection, ...
                "max_deflection_m", AbsTol=1e-12);
            test.verifyEqual(result.safety_factor, expected_sf, ...
                "safety_factor", AbsTol=1e-10);
        end

        function beamStressPass(test)
            % Yield strength well above max stress => PASS
            result = calculateBeamStress(1000, 1.0, 0.05, 0.1, 200e9, 500e6);
            test.verifyEqual(result.status, "PASS");
            test.verifyGreaterThan(result.safety_factor, 1.0);
        end

        function beamStressFail(test)
            % Yield strength below max stress => FAIL
            % Large load, small cross-section, weak material
            result = calculateBeamStress(100000, 3.0, 0.02, 0.02, 200e9, 1e6);
            test.verifyEqual(result.status, "FAIL");
            test.verifyLessThan(result.safety_factor, 1.0);
        end

        function thermalResistanceKnownValues(test)
            % Flat plate: thickness=0.003m, area=0.04m^2, k=388 W/(m*K)
            % T_hot=100C, T_cold=25C

            thickness = 0.003;
            area = 0.04;
            k = 388;
            T_hot = 100;
            T_cold = 25;

            result = calculateThermalResistance(thickness, area, k, ...
                T_hot, T_cold);

            % Expected values (hand-calculated)
            expected_R = thickness / (k * area);
            expected_Q = (T_hot - T_cold) / expected_R;
            expected_q = expected_Q / area;
            expected_T_mid = (T_hot + T_cold) / 2;

            test.verifyEqual(result.thermal_resistance_KperW, expected_R, ...
                "thermal_resistance_KperW", AbsTol=1e-12);
            test.verifyEqual(result.heat_transfer_rate_W, expected_Q, ...
                "heat_transfer_rate_W", AbsTol=1e-6);
            test.verifyEqual(result.heat_flux_Wperm2, expected_q, ...
                "heat_flux_Wperm2", AbsTol=1e-6);
            test.verifyEqual(result.midpoint_temperature_C, expected_T_mid, ...
                "midpoint_temperature_C", AbsTol=1e-12);
        end

        function thermalMidpointTemperature(test)
            % Midpoint temperature is always the average of boundary temps,
            % regardless of material or geometry.
            T_hot = 200;
            T_cold = 50;
            result = calculateThermalResistance(0.01, 0.1, 50, T_hot, T_cold);
            test.verifyEqual(result.midpoint_temperature_C, ...
                (T_hot + T_cold) / 2);
        end

    end
end
