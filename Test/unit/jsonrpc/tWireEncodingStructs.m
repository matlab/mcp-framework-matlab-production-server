classdef tWireEncodingStructs < prodserver.mcp.test.base.MCPHandlerBase
% Test wire encoding round-trip for nested struct arguments via mcpHandler.

% Copyright 2026 The MathWorks, Inc.

    methods (TestClassSetup)

        function prepareTools(test)
            import matlab.unittest.fixtures.PathFixture

            % Add package root to path
            testFolder = fileparts(mfilename("fullpath"));
            pkgFolder = fullfile(testFolder, "..", "..", "..");
            test.applyFixture(PathFixture(pkgFolder));

            % Add StructuredData example to path
            test.applyFixture(PathFixture( ...
                fullfile(pkgFolder, "Examples", "StructuredData")));

            % Add server tools to path
            test.applyFixture(PathFixture( ...
                fullfile(prodserver.mcp.internal.packageFolder(), ...
                         "server", "tools")));

            test.fcnNames = ["circlesIntersect", "analyzeBeam"];
            test.toolNames = ["circlesIntersect", "analyzeBeam"];
            defineTools(test, test.fcnNames, test.toolNames);
        end

    end

    methods (Access = private)

        function reqT = buildToolCallRequest(test, toolName, arguments)
            import prodserver.mcp.MCPConstants

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}];
            req.Headers = [req.Headers; ...
                {MCPConstants.SessionId, matlab.lang.internal.uuid}];

            body = jsonencode(struct( ...
                'jsonrpc', "2.0", ...
                'id', 1, ...
                'method', "tools/call", ...
                'params', struct( ...
                    'name', toolName, ...
                    'arguments', arguments)));

            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/StructuredData/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body, "UTF-8");
        end

    end

    methods (Test)

        function circlesIntersect_nestedInput(test)
            c1 = struct('radius', 5, 'origin', struct('x', 0, 'y', 0));
            c2 = struct('radius', 3, 'origin', struct('x', 6, 'y', 0));

            reqT = buildToolCallRequest(test, "circlesIntersect", ...
                struct('c1', c1, 'c2', c2));

            response = prodserver.mcp.internal.mcpHandler(reqT);
            response = decodeResponse(test,reqT,response);

            if isfield(response.result, "isError")
                test.assertFalse(response.result.isError, ...
                    response.result.content.text);
            end
            test.verifyEqual(response.id, 1);

            localResult = circlesIntersect(c1, c2);
            test.verifyEqual( ...
                logical(response.result.structuredContent.tf), ...
                localResult, "tf");
        end

        function analyzeBeam_rectangularPointLoad(test)
            beam = struct( ...
                'material', struct('youngs_modulus', 200e9, 'density', 7800), ...
                'cross_section', struct('shape', 'rectangular', ...
                    'width', 0.05, 'height', 0.1), ...
                'length', 3.0);
            load = struct('type', 'point', 'magnitude', 5000, 'position', 1.5);

            reqT = buildToolCallRequest(test, "analyzeBeam", ...
                struct('beam_spec', beam, 'load_case', load));

            response = prodserver.mcp.internal.mcpHandler(reqT);
            response = decodeResponse(test,reqT,response);

            if isfield(response.result, "isError")
                test.assertFalse(response.result.isError, ...
                    response.result.content.text);
            end
            test.verifyEqual(response.id, 1);

            localResult = analyzeBeam(beam, load);
            sc = response.result.structuredContent.result;
            test.verifyEqual(sc.max_stress_Pa, ...
                localResult.max_stress_Pa, "max_stress_Pa", AbsTol=1e-4);
            test.verifyEqual(sc.max_deflection_m, ...
                localResult.max_deflection_m, "max_deflection_m", AbsTol=1e-10);
            test.verifyEqual(sc.natural_frequency_Hz, ...
                localResult.natural_frequency_Hz, "frequency", AbsTol=1e-4);
        end

        function analyzeBeam_circularDistributed(test)
            beam = struct( ...
                'material', struct('youngs_modulus', 70e9, 'density', 2700), ...
                'cross_section', struct('shape', 'circular', ...
                    'diameter', 0.06), ...
                'length', 2.0);
            load = struct('type', 'distributed', 'magnitude', 1500, ...
                'position', 0);

            reqT = buildToolCallRequest(test, "analyzeBeam", ...
                struct('beam_spec', beam, 'load_case', load));

            response = prodserver.mcp.internal.mcpHandler(reqT);
            response = decodeResponse(test,reqT,response);

            if isfield(response.result, "isError")
                test.assertFalse(response.result.isError, ...
                    response.result.content.text);
            end
            test.verifyEqual(response.id, 1);

            localResult = analyzeBeam(beam, load);
            sc = response.result.structuredContent.result;
            test.verifyEqual(sc.max_stress_Pa, ...
                localResult.max_stress_Pa, "max_stress_Pa", AbsTol=1e-4);
            test.verifyEqual(sc.max_deflection_m, ...
                localResult.max_deflection_m, "max_deflection_m", AbsTol=1e-10);
        end

        function beamSchemaInToolDefinition(test)
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}];
            req.Headers = [req.Headers; ...
                {MCPConstants.SessionId, matlab.lang.internal.uuid}];

            body = '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}';

            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/StructuredData/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body, "UTF-8");

            response = prodserver.mcp.internal.mcpHandler(reqT);
            response = decodeResponse(test,reqT,response);

            test.verifyEqual(response.id, 1);
            test.verifyTrue(hasField(response, 'result.tools'));

            tools = response.result.tools;
            if iscell(tools)
                names = cellfun(@(t)string(t.name), tools);
                beamTool = tools{names == "analyzeBeam"};
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
