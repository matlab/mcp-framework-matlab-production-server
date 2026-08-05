classdef tStructuredDataCalculations < matlab.unittest.TestCase
% Unit tests for circlesIntersect and analyzeBeam.

% Copyright 2026 The MathWorks, Inc.

    methods (TestClassSetup)

        function addExampleToPath(test)
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            exampleFolder = fullfile(testFolder, "..", "..", "..", ...
                "Examples", "StructuredData");
            test.applyFixture(PathFixture(exampleFolder));
        end

    end

    methods (Test)

        function circlesIntersect_overlapping(test)
            c1 = struct('radius', 5, 'origin', struct('x', 0, 'y', 0));
            c2 = struct('radius', 3, 'origin', struct('x', 6, 'y', 0));
            tf = circlesIntersect(c1, c2);
            test.verifyTrue(tf);
        end

        function circlesIntersect_separate(test)
            c1 = struct('radius', 2, 'origin', struct('x', 0, 'y', 0));
            c2 = struct('radius', 2, 'origin', struct('x', 10, 'y', 0));
            tf = circlesIntersect(c1, c2);
            test.verifyFalse(tf);
        end

        function circlesIntersect_touching(test)
            c1 = struct('radius', 3, 'origin', struct('x', 0, 'y', 0));
            c2 = struct('radius', 4, 'origin', struct('x', 7, 'y', 0));
            tf = circlesIntersect(c1, c2);
            test.verifyTrue(tf);
        end

        function circlesIntersect_matrix(test)
            c1(1) = struct('radius', 5, 'origin', struct('x', 0, 'y', 0));
            c1(2) = struct('radius', 1, 'origin', struct('x', 100, 'y', 100));
            c2(1) = struct('radius', 3, 'origin', struct('x', 6, 'y', 0));
            c2(2) = struct('radius', 1, 'origin', struct('x', 0, 'y', 0));

            tf = circlesIntersect(c1, c2);

            test.verifyEqual(size(tf), [2 2]);
            test.verifyTrue(tf(1,1));   % c1(1) overlaps c2(1)
            test.verifyTrue(tf(1,2));   % c1(1) overlaps c2(2)
            test.verifyFalse(tf(2,1));  % c1(2) far from c2(1)
            test.verifyFalse(tf(2,2));  % c1(2) far from c2(2)
        end

        function analyzeBeam_rectangularPointLoad(test)
            beam = struct( ...
                'material', struct('youngs_modulus', 200e9, 'density', 7800), ...
                'cross_section', struct('shape', 'rectangular', ...
                    'width', 0.05, 'height', 0.1), ...
                'length', 3.0);
            load = struct('type', 'point', 'magnitude', 5000, 'position', 1.5);

            result = analyzeBeam(beam, load);

            % Hand-calculated expected values
            I = (0.05 * 0.1^3) / 12;          % 4.1667e-06 m^4
            M_max = (5000 * 1.5 * 1.5) / 3.0; % 3750 N*m
            expected_stress = (M_max * 0.05) / I;
            expected_deflection = (5000 * 3.0^3) / (48 * 200e9 * I);

            test.verifyEqual(result.max_stress_Pa, expected_stress, ...
                "max_stress_Pa", AbsTol=1e-6);
            test.verifyEqual(result.max_deflection_m, expected_deflection, ...
                "max_deflection_m", AbsTol=1e-12);
            test.verifyEqual(result.second_moment_of_area_m4, I, ...
                "I", AbsTol=1e-15);
            test.verifyEqual(result.cross_section_area_m2, 0.05*0.1, ...
                "area", AbsTol=1e-15);
        end

        function analyzeBeam_circularPointLoad(test)
            d = 0.08;
            beam = struct( ...
                'material', struct('youngs_modulus', 70e9, 'density', 2700), ...
                'cross_section', struct('shape', 'circular', ...
                    'diameter', d), ...
                'length', 2.0);
            load = struct('type', 'point', 'magnitude', 3000, 'position', 1.0);

            result = analyzeBeam(beam, load);

            I = pi * d^4 / 64;
            A = pi * d^2 / 4;
            M_max = (3000 * 1.0 * 1.0) / 2.0;
            expected_stress = (M_max * d/2) / I;
            expected_deflection = (3000 * 2.0^3) / (48 * 70e9 * I);

            test.verifyEqual(result.max_stress_Pa, expected_stress, ...
                "max_stress_Pa", AbsTol=1e-4);
            test.verifyEqual(result.max_deflection_m, expected_deflection, ...
                "max_deflection_m", AbsTol=1e-12);
            test.verifyEqual(result.second_moment_of_area_m4, I, ...
                "I", AbsTol=1e-15);
            test.verifyEqual(result.cross_section_area_m2, A, ...
                "area", AbsTol=1e-15);
        end

        function analyzeBeam_distributedLoad(test)
            beam = struct( ...
                'material', struct('youngs_modulus', 200e9, 'density', 7800), ...
                'cross_section', struct('shape', 'rectangular', ...
                    'width', 0.04, 'height', 0.08), ...
                'length', 4.0);
            load = struct('type', 'distributed', 'magnitude', 2000, ...
                'position', 0);

            result = analyzeBeam(beam, load);

            I = (0.04 * 0.08^3) / 12;
            M_max = (2000 * 4.0^2) / 8;
            expected_stress = (M_max * 0.04) / I;
            expected_deflection = (5 * 2000 * 4.0^4) / (384 * 200e9 * I);

            test.verifyEqual(result.max_stress_Pa, expected_stress, ...
                "max_stress_Pa", AbsTol=1e-4);
            test.verifyEqual(result.max_deflection_m, expected_deflection, ...
                "max_deflection_m", AbsTol=1e-10);
        end

        function analyzeBeam_naturalFrequency(test)
            E = 200e9; rho = 7800; L = 2.5;
            w = 0.03; h = 0.06;
            beam = struct( ...
                'material', struct('youngs_modulus', E, 'density', rho), ...
                'cross_section', struct('shape', 'rectangular', ...
                    'width', w, 'height', h), ...
                'length', L);
            load = struct('type', 'point', 'magnitude', 1000, 'position', 1.25);

            result = analyzeBeam(beam, load);

            I = (w * h^3) / 12;
            A = w * h;
            expected_f = (pi / (2 * L^2)) * sqrt((E * I) / (rho * A));

            test.verifyEqual(result.natural_frequency_Hz, expected_f, ...
                "natural_frequency_Hz", AbsTol=1e-6);
        end

    end
end
