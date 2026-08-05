classdef tStructuredDataServer < matlab.unittest.TestCase
% Integration test: build, deploy and call the StructuredData MCP servers.

% Copyright 2026 The MathWorks, Inc.

    properties
        server
        host
        port
        exampleFolder
        circlesEndpoint
        beamEndpoint
    end

    methods (TestClassSetup)

        function requireActiveServer(test)
            test.server = getenv(prodserver.mcp.MCPConstants.TestServerEnvVar);
            test.assertTrue(~isempty(test.server), ...
                "Set environment variable " + ...
                prodserver.mcp.MCPConstants.TestServerEnvVar + ...
                " to network address of MPS instance for testing.");

            healthQuery = test.server + "/api/health";
            response = webread(healthQuery);
            test.assertTrue(strcmp(response.status, "ok"), ...
                "Invalid response to health query: " + response.status);

            hostPattern = lookBehindBoundary(textBoundary("start") + ...
                wildcardPattern("Except", ":") + "://") + ...
                wildcardPattern("Except", ":") + ...
                lookAheadBoundary(characterListPattern(":/") | ...
                textBoundary("end"));
            test.host = string(extract(test.server, hostPattern));
            portPattern = lookBehindBoundary(wildcardPattern + ...
                test.host + ":") + wildcardPattern + textBoundary("end");
            test.port = string(extract(test.server, portPattern));
        end

        function addExampleToPath(test)
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            test.exampleFolder = fullfile(testFolder, "..", "..", "..", ...
                "Examples", "StructuredData");
            test.applyFixture(PathFixture(test.exampleFolder));
        end

        function registerPackage(test)
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            pkgFolder = fullfile(testFolder, "..", "..", "..");
            test.applyFixture(PathFixture(pkgFolder));
        end

        function buildAndDeployCircles(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            archive = "CirclesIntTest";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive( ...
                test.server, archive));

            tfolder = TemporaryFolderFixture;
            applyFixture(test, tfolder);

            ctf = prodserver.mcp.build("circlesIntersect", ...
                archive=archive, ...
                wrapper="None", ...
                folder=tfolder.Folder);
            test.assertNotEmpty(ctf);

            test.circlesEndpoint = prodserver.mcp.deploy( ...
                ctf, test.host, test.port);
        end

        function buildAndDeployBeam(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            archive = "BeamIntTest";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive( ...
                test.server, archive));

            tfolder = TemporaryFolderFixture;
            applyFixture(test, tfolder);

            ctf = prodserver.mcp.build("analyzeBeam", ...
                archive=archive, ...
                wrapper="None", ...
                encoding="JSON", ...
                folder=tfolder.Folder);
            test.assertNotEmpty(ctf);

            test.beamEndpoint = prodserver.mcp.deploy( ...
                ctf, test.host, test.port);
        end

    end

    methods (Test)

        function circlesToolExists(test)
            test.verifyTrue(prodserver.mcp.exist( ...
                test.circlesEndpoint, "circlesIntersect", "Tool"));
        end

        function beamToolExists(test)
            test.verifyTrue(prodserver.mcp.exist( ...
                test.beamEndpoint, "analyzeBeam", "Tool"));
        end

        function callCirclesIntersect(test)
            c1 = struct('radius', 5, 'origin', struct('x', 0, 'y', 0));
            c2 = struct('radius', 3, 'origin', struct('x', 6, 'y', 0));

            mcpResult = prodserver.mcp.call( ...
                test.circlesEndpoint, "circlesIntersect", c1, c2);

            localResult = circlesIntersect(c1, c2);
            test.verifyEqual(logical(mcpResult), localResult, "intersect");
        end

        function callCirclesSeparate(test)
            c1 = struct('radius', 1, 'origin', struct('x', 0, 'y', 0));
            c2 = struct('radius', 1, 'origin', struct('x', 50, 'y', 50));

            mcpResult = prodserver.mcp.call( ...
                test.circlesEndpoint, "circlesIntersect", c1, c2);

            test.verifyFalse(logical(mcpResult));
        end

        function callBeamRectangular(test)
            beam = struct( ...
                'material', struct('youngs_modulus', 200e9, 'density', 7800), ...
                'cross_section', struct('shape', 'rectangular', ...
                    'width', 0.05, 'height', 0.1), ...
                'length', 3.0);
            load = struct('type', 'point', 'magnitude', 5000, 'position', 1.5);

            mcpResult = prodserver.mcp.call( ...
                test.beamEndpoint, "analyzeBeam", beam, load);

            localResult = analyzeBeam(beam, load);

            test.verifyEqual(mcpResult.max_stress_Pa, ...
                localResult.max_stress_Pa, "max_stress_Pa", AbsTol=1e-4);
            test.verifyEqual(mcpResult.max_deflection_m, ...
                localResult.max_deflection_m, "max_deflection_m", AbsTol=1e-10);
            test.verifyEqual(mcpResult.natural_frequency_Hz, ...
                localResult.natural_frequency_Hz, "frequency", AbsTol=1e-4);
        end

        function callBeamDistributed(test)
            beam = struct( ...
                'material', struct('youngs_modulus', 70e9, 'density', 2700), ...
                'cross_section', struct('shape', 'circular', ...
                    'diameter', 0.06), ...
                'length', 2.0);
            load = struct('type', 'distributed', 'magnitude', 1500, ...
                'position', 0);

            mcpResult = prodserver.mcp.call( ...
                test.beamEndpoint, "analyzeBeam", beam, load);

            localResult = analyzeBeam(beam, load);

            test.verifyEqual(mcpResult.max_stress_Pa, ...
                localResult.max_stress_Pa, "max_stress_Pa", AbsTol=1e-4);
            test.verifyEqual(mcpResult.max_deflection_m, ...
                localResult.max_deflection_m, "max_deflection_m", AbsTol=1e-10);
        end

        function beamSchemaInDefinition(test)
            tools = prodserver.mcp.list(test.beamEndpoint, "Tool");
            if iscell(tools)
                names = cellfun(@(t)t.name, tools, UniformOutput=false);
                idx = strcmp(names, "analyzeBeam");
                beamTool = tools{idx};
            else
                beamTool = tools(strcmp({tools.name}, "analyzeBeam"));
            end
            test.assertNotEmpty(beamTool, "analyzeBeam not found");

            props = beamTool.inputSchema.properties;
            test.verifyTrue(isfield(props, "beam_spec"), ...
                "beam_spec missing from schema");
            test.verifyTrue(isfield(props, "load_case"), ...
                "load_case missing from schema");
        end

    end
end
