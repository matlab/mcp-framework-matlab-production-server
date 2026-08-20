classdef tWireEncodingTools < prodserver.mcp.test.base.MCPHandlerBase
% Test wire encoding round-trip for WireEncoding example tools via mcpHandler.
%
% Verifies that complex numbers, NaN, integer types, and vector
% orientation survive the JSON-RPC encode/decode cycle without requiring
% a running MPS instance.

% Copyright 2026 The MathWorks, Inc.

    properties
        dataFolder
    end

    methods (TestClassSetup)

        function prepareTools(test)
            import matlab.unittest.fixtures.PathFixture

            testFolder = fileparts(mfilename("fullpath"));
            pkgFolder = fullfile(testFolder, "..", "..", "..");
            test.applyFixture(PathFixture(pkgFolder));

            % Add WireEncoding example to path
            test.applyFixture(PathFixture( ...
                fullfile(pkgFolder, "Examples", "WireEncoding")));

            % Add server tools to path
            test.applyFixture(PathFixture( ...
                fullfile(prodserver.mcp.internal.packageFolder(), ...
                         "server", "tools")));

            test.dataFolder = fullfile(testFolder, "..", "..", ...
                "data", "examples", "WireEncoding");

            test.fcnNames = ["matrixMultiply", "analyzeACCircuit", ...
                "interpolateWithMissing", "fuseSensors", "blendImages"];
            test.toolNames = test.fcnNames;
            defineTools(test, test.fcnNames, test.toolNames,encoding="Invertible");

        end

    end

    methods (Test)

        % --- matrixMultiply: orientation ---

        function matrixMultiply_dotProduct(test)
            args = struct( ...
                'A', struct('type','double','size',[1,3],'data',[1,2,3]), ...
                'B', struct('type','double','size',[3,1],'data',[4,5,6]));
            response = callTool(test, "matrixMultiply", args);
            verifyNoError(test, response);
            C = response.result.structuredContent.C;
            test.verifyEqual(C, 32, AbsTol=1e-10);
        end

        function matrixMultiply_outerProduct(test)
            args = struct( ...
                'A', struct('type','double','size',[3,1],'data',[2,3,4]), ...
                'B', struct('type','double','size',[1,3],'data',[10,20,30]));
            response = callTool(test, "matrixMultiply", args);
            verifyNoError(test, response);
            C = response.result.structuredContent.C;
            expected = [2;3;4] * [10 20 30];
            test.verifyEqual(C, expected, AbsTol=1e-10);
            test.verifySize(C, [3 3]);
        end

        function matrixMultiply_matrixTimesVector(test)
            % 2x3 matrix * 3x1 vector -> 2x1 vector
            args = struct( ...
                'A', struct('type','double','size',[2,3],'data',[1,2,3,4,5,6]), ...
                'B', struct('type','double','size',[3,1],'data',[1,1,1]));
            response = callTool(test, "matrixMultiply", args);
            verifyNoError(test, response);
            C = response.result.structuredContent.C;
            % [1,2,3;4,5,6]*[1;1;1] = [6;15]
            test.verifyEqual(C, [6;15], AbsTol=1e-10);
        end

        % --- analyzeACCircuit: complex output ---

        function analyzeACCircuit_complexOutput(test)
            args = struct('R',100, 'L',0.1, 'C',10e-6, ...
                'frequency',60, 'Vsource',120);
            response = callTool(test, "analyzeACCircuit", args);
            verifyNoError(test, response);
            Z = response.result.structuredContent.Z_total;
            test.verifyFalse(isreal(Z), "Z_total must be complex");
            % At 60 Hz: Z_L = j*2*pi*60*0.1 = j*37.7
            % Z_C = 1/(j*2*pi*60*10e-6) = -j*265.3
            % Z_total = 100 + j*37.7 - j*265.3 = 100 - j*227.6
            test.verifyEqual(real(Z), 100, AbsTol=1);
            test.verifyLessThan(imag(Z), 0);
        end

        function analyzeACCircuit_frequencyVector(test)
            freq = struct('type','double','size',[5,1], ...
                'data',[100,500,1000,5000,10000]);
            args = struct('R',8, 'L',1.2e-3, 'C',22e-6, ...
                'frequency',freq, 'Vsource',10);
            response = callTool(test, "analyzeACCircuit", args);
            verifyNoError(test, response);
            Z = response.result.structuredContent.Z_total;
            test.verifyFalse(isreal(Z), "Z_total must be complex");
            test.verifySize(Z, [5 1]);
        end

        function analyzeACCircuit_allOutputsComplex(test)
            args = struct('R',50, 'L',0.01, 'C',1e-6, ...
                'frequency',1000, 'Vsource',10);
            response = callTool(test, "analyzeACCircuit", args);
            verifyNoError(test, response);
            sc = response.result.structuredContent;
            fields = ["Z_total","I_total","V_R","V_L","V_C"];
            for f = fields
                test.verifyFalse(isreal(sc.(f)), f + " must be complex");
            end
        end

        % --- interpolateWithMissing: NaN handling ---

        function interpolateWithMissing_nanBridged(test)
            t = struct('type','double','size',[11,1], ...
                'data',[0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0]);
            signal = struct('type','double','size',[11,1], ...
                'data',{{0, 0.59, "NaN", 0.95, "NaN", "NaN", ...
                         -0.59, -0.81, -0.95, -1.0, -0.84}});
            args = struct('t',t, 'signal',signal, 't_query',t);
            response = callTool(test, "interpolateWithMissing", args);
            verifyNoError(test, response);
            recon = response.result.structuredContent.reconstructed;
            test.verifyFalse(any(isnan(recon)), ...
                "Reconstructed signal must have no NaN");
            test.verifySize(recon, [11 1]);
        end

        function interpolateWithMissing_gapMask(test)
            t = struct('type','double','size',[5,1],'data',[0,1,2,3,4]);
            signal = struct('type','double','size',[5,1], ...
                'data',{{1.0, "NaN", 3.0, "NaN", 5.0}});
            args = struct('t',t, 'signal',signal, 't_query',t);
            response = callTool(test, "interpolateWithMissing", args);
            verifyNoError(test, response);
            mask = response.result.structuredContent.gapMask;
            % Positions 2 and 4 should be gaps
            test.verifyTrue(mask(2), "Position 2 should be gap");
            test.verifyTrue(mask(4), "Position 4 should be gap");
            test.verifyFalse(mask(1), "Position 1 is not gap");
            test.verifyFalse(mask(3), "Position 3 is not gap");
        end

        % --- fuseSensors: integer type dispatch ---

        function fuseSensors_uint8VsUint16(test)
            s1 = struct('type','uint8','size',[1,5], ...
                'data',[128,130,127,131,129]);
            s2 = struct('type','uint16','size',[1,5], ...
                'data',[32768,32770,32766,32771,32769]);
            args = struct('sensor1',s1, 'sensor2',s2);
            response = callTool(test, "fuseSensors", args);
            verifyNoError(test, response);
            sc = response.result.structuredContent;
            w = sc.weights;
            % uint16 (sensor2) should get much higher weight
            test.verifyGreaterThan(w(2), 0.99, ...
                "16-bit sensor should get >99% weight over 8-bit");
        end

        function fuseSensors_doubleVsUint8(test)
            s1 = struct('type','double','size',[1,3],'data',[0.5,0.51,0.49]);
            s2 = struct('type','uint8','size',[1,3],'data',[128,130,126]);
            args = struct('sensor1',s1, 'sensor2',s2);
            response = callTool(test, "fuseSensors", args);
            verifyNoError(test, response);
            sc = response.result.structuredContent;
            w = sc.weights;
            % double (sensor1) should get near-100% weight
            test.verifyGreaterThan(w(1), 0.99, ...
                "Double sensor should get >99% weight over uint8");
        end

        % --- blendImages: integer type preservation ---

        function blendImages_uint8Output(test)
            A = struct('type','uint8','size',[2,2],'data',[200,180,220,240]);
            B = struct('type','uint8','size',[2,2],'data',[50,60,40,30]);
            args = struct('A',A, 'B',B, 'alpha',0.7);
            response = callTool(test, "blendImages", args);
            verifyNoError(test, response);
            result = response.result.structuredContent.result;
            test.verifyClass(result, 'uint8');
            test.verifySize(result, [2 2]);
        end

        function blendImages_int16Output(test)
            A = struct('type','int16','size',[2,2], ...
                'data',[1000,-500,2000,-1000]);
            B = struct('type','int16','size',[2,2], ...
                'data',[-1000,500,-2000,1000]);
            args = struct('A',A, 'B',B, 'alpha',0.5);
            response = callTool(test, "blendImages", args);
            verifyNoError(test, response);
            result = response.result.structuredContent.result;
            test.verifyClass(result, 'int16');
            test.verifySize(result, [2 2]);
        end

        function blendImages_doubleOutput(test)
            A = struct('type','double','size',[2,2], ...
                'data',[0.8,0.2,0.9,0.1]);
            B = struct('type','double','size',[2,2], ...
                'data',[0.1,0.9,0.2,0.8]);
            args = struct('A',A, 'B',B, 'alpha',0.6);
            response = callTool(test, "blendImages", args);
            verifyNoError(test, response);
            result = response.result.structuredContent.result;
            % Wire data [0.8,0.2,0.9,0.1] with size [2,2] is row-major:
            % row1=[0.8,0.2], row2=[0.9,0.1] -> MATLAB [0.8 0.2; 0.9 0.1]
            localResult = blendImages([0.8 0.2; 0.9 0.1], ...
                [0.1 0.9; 0.2 0.8], 0.6);
            test.verifyEqual(result, localResult, AbsTol=1e-10);
        end

    end

    methods (Access=private)

        function response = callTool(test, toolName, arguments)
            import prodserver.mcp.MCPConstants

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}; ...
                {MCPConstants.SessionId, matlab.lang.internal.uuid}];

            body = jsonencode(struct( ...
                'jsonrpc', "2.0", ...
                'id', 1, ...
                'method', "tools/call", ...
                'params', struct( ...
                    'name', toolName, ...
                    'arguments', arguments)));

            req.Method = "POST";
            req.Path = "/WireEncoding/mcp";
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            req.Body = unicode2native(body, "UTF-8");

            response = prodserver.mcp.internal.mcpHandler(req);
            response = decodeResponse(test,req,response);
        end

        function verifyNoError(test, response)
            if isfield(response, 'result') && ...
                    isfield(response.result, 'isError') && ...
                    response.result.isError
                test.assertFalse(true, ...
                    "Tool call returned error: " + ...
                    response.result.content.text);
            end
        end

    end
end
