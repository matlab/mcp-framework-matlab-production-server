%% Wire Encoding for Numeric Data
% Build a five-tool MCP server demonstrating how wire encoding preserves
% vector orientation, complex numbers, NaN, and integer types.

% Copyright 2026 The MathWorks, Inc.

% Deploy to this MATLAB Production Server unless another one already
% specified.
if isempty(mpsServer)
    mpsServer = "http://localhost:9910";
end

%% Build and Deploy
% |buildWireEncodingServer| packages all five tools and ten data resources.

[ctf, endpoint] = buildWireEncodingServer(host=mpsServer);

%% Verify Deployment

prodserver.mcp.ping(endpoint)
tools = prodserver.mcp.list(endpoint, "Tool");
cellfun(@(t) t.name, tools, 'UniformOutput', false)

%% Matrix Multiply: Vector Orientation
% Dot product (1x3 * 3x1 = scalar) vs outer product (3x1 * 1x3 = 3x3).

C_dot = prodserver.mcp.call(endpoint, "matrixMultiply", [1 2 3], [4;5;6])
C_outer = prodserver.mcp.call(endpoint, "matrixMultiply", [4;5;6], [1 2 3])

%% AC Circuit Analysis: Complex Numbers
% Series RLC circuit swept from 100 Hz to 22 kHz. Output is complex-valued.

freq = logspace(2, 4.3, 20)';
[Z, I, V_R, V_L, V_C] = prodserver.mcp.call(endpoint, ...
    "analyzeACCircuit", 8, 1.2e-3, 22e-6, freq, 10);

figure
subplot(2,1,1); plot(freq, abs(Z)); title("|Z| vs Frequency");
xlabel("Hz"); ylabel("Ohms");
subplot(2,1,2); plot(freq, angle(Z)*180/pi); title("Phase vs Frequency");
xlabel("Hz"); ylabel("Degrees");

%% Interpolation: NaN Preservation
% Vibration sensor signal with NaN dropout bursts.

dataDir = fullfile(fileparts(mfilename("fullpath")), "data");
data = readtable(fullfile(dataDir, "vibration_sensor.csv"), "CommentStyle", "#");

[reconstructed, gapMask] = prodserver.mcp.call(endpoint, ...
    "interpolateWithMissing", data.time_s, data.acceleration_g, data.time_s);

figure
plot(data.time_s, data.acceleration_g, 'r.', data.time_s, reconstructed, 'b-');
legend("Original (with NaN)", "Reconstructed");
title("Vibration Sensor Gap Reconstruction");

%% Sensor Fusion: Integer Type Dispatch
% Laser (double) and ultrasonic (uint16) rangefinder fusion.

data = readtable(fullfile(dataDir, "rangefinder_sensors.csv"), "CommentStyle", "#");
[fused, weights, uncertainty] = prodserver.mcp.call(endpoint, ...
    "fuseSensors", data.laser_m, uint16(data.ultrasonic_mm_uint16));

fprintf("Fusion weights: laser=%.3f, ultrasonic=%.3f\n", weights(1), weights(2));

%% Image Blending: Type-Dependent Arithmetic
% Temporal noise reduction on uint8 thermal frames.

A = uint8(readmatrix(fullfile(dataDir, "thermal_frame_A.csv"), "CommentStyle", "#"));
B = uint8(readmatrix(fullfile(dataDir, "thermal_frame_B.csv"), "CommentStyle", "#"));
result = prodserver.mcp.call(endpoint, "blendImages", A, B, 0.6);

fprintf("Result class: %s (preserves uint8)\n", class(result));

%% Connect an MCP Client
% Configure your client to connect to:
%
%   http://localhost:9910/WireEncoding/mcp
%
% Then try this prompt:
%
%   Compute the dot product of [1, 2, 3] and [4, 5, 6].
%
%   Analyze the audio crossover filter (R=8 Ohm, L=1.2 mH, C=22 uF,
%   Vs=10 V) across a frequency sweep from 100 Hz to 22 kHz.


