%[text] # Wire Encoding for Numeric Data
%[text] This live script builds and deploys the Wire Encoding demonstration server, then exercises each of the five tools to show how the MCP Framework wire encoding preserves vector orientation, complex numbers, NaN values, and integer types through JSON-RPC transport.
%[text:table]
%[text] | Tool | Wire Encoding Need |
%[text] | --- | --- |
%[text] | matrixMultiply | Vector/matrix orientation |
%[text] | analyzeACCircuit | Complex number output |
%[text] | interpolateWithMissing | NaN (missing data) preservation |
%[text] | fuseSensors | Integer type dispatch (heterogeneous) |
%[text] | blendImages | Integer type dispatch (saturation) |
%[text:table]
%[text] ## Build and Deploy
[~, endpoint] = buildWireEncodingServer(host="localhost", port=9910);
disp("Server deployed at: " + endpoint)
%[text] ## Matrix Multiply: Orientation Matters
%[text] Without wire encoding, `[1,2,3]` and `[4,5,6]` both arrive as 3x1 column vectors via `jsondecode`. The multiplication (3x1)\*(3x1) is a **dimension error**. With wire encoding, orientation is preserved. \#\#\# Dot product (1x3 \* 3x1 -\> scalar)
C = prodserver.mcp.call(endpoint, "matrixMultiply", [1 2 3], [4;5;6])
%[text] ### Outer product (3x1 \* 1x3 -\> 3x3 matrix)
C = prodserver.mcp.call(endpoint, "matrixMultiply", [4;5;6], [1 2 3])
%[text] ### Rotation matrix  *vector (3x3*  3x1 -\> 3x1)
R = [cosd(45) -sind(45) 0; sind(45) cosd(45) 0; 0 0 1];
v = [1; 0; 0];
C = prodserver.mcp.call(endpoint, "matrixMultiply", R, v)
%[text] ## Analyze AC Circuit: Complex Outputs
%[text] Computes complex impedance, current, and voltages for a series RLC%\[text\] circuit across a frequency sweep. All outputs are complex phasors that JSON simply cannot represent.
%[text] ### Audio crossover network (R=8 Ohm, L=1.2 mH, C=22 uF)
freq = logspace(2, 4.3, 20)';
[Z_total, I_total, V_R, V_L, V_C] = prodserver.mcp.call(endpoint, ...
    "analyzeACCircuit", 8, 1.2e-3, 22e-6, freq, 10);

figure
subplot(2,1,1)
semilogx(freq, abs(Z_total))
xlabel("Frequency (Hz)")
ylabel("|Z| (Ohms)")
title("Impedance Magnitude")
grid on

subplot(2,1,2)
semilogx(freq, angle(Z_total)*180/pi)
xlabel("Frequency (Hz)")
ylabel("Phase (degrees)")
title("Impedance Phase")
grid on

%[text] ## Interpolate With Missing: NaN Preservation
%[text] NaN marks sensor dropout. JSON has no NaN literal, so without wire encoding the gaps become 0 and the interpolation fits a wrong curve.
dataDir = fullfile(fileparts(which("buildWireEncodingServer")), "..", "..", ...
    "Test", "data", "examples", "WireEncoding");

data = readtable(fullfile(dataDir, "vibration_sensor.csv"), "CommentStyle", "#");
t = data.time_s;
signal = data.acceleration_g;

[reconstructed, gapMask] = prodserver.mcp.call(endpoint, ...
    "interpolateWithMissing", t, signal, t);

figure
plot(t, signal, 'r.', 'MarkerSize', 10, 'DisplayName', 'Original (with NaN)')
hold on
plot(t(gapMask), reconstructed(gapMask), 'bo', ...
    'MarkerSize', 8, 'DisplayName', 'Interpolated gaps')
plot(t, reconstructed, 'k-', 'DisplayName', 'Reconstructed')
hold off
xlabel("Time (s)")
ylabel("Acceleration (g)")
title("Vibration Sensor: Bridging NaN Dropouts")
legend('Location', 'best')
grid on

%[text] ## Fuse Sensors: Integer Type Dispatch
%[text] The fusion weights each sensor inversely to its quantization noise, which is derived from the numeric type (`uint8`, `uint16`, or `double`). Without wire encoding, both arrive as `double` and get **equal weight**. \#\#\# Laser (double) vs ultrasonic (uint16) rangefinder
data = readtable(fullfile(dataDir, "rangefinder_sensors.csv"), "CommentStyle", "#");
laser = data.laser_m;
ultrasonic = uint16(data.ultrasonic_mm_uint16);

[fused, weights, uncertainty] = prodserver.mcp.call(endpoint, ...
    "fuseSensors", laser, ultrasonic);

disp("Fusion weights: laser=" + weights(1) + ", ultrasonic=" + weights(2))
disp("Uncertainty: " + uncertainty)
%[text] The laser (double precision) gets near-100% weight because its quantization noise is essentially zero compared to the 16-bit ADC. 
%[text] ## Blend Images: Type-Dependent Arithmetic 
%[text] Image type determines blending behavior: `uint8` uses saturating arithmetic clamped to \[0,255\], `int16` supports negative values, and `double` is unclamped HDR. Without wire encoding, the type is always `double`.
%[text] ### Thermal camera noise reduction (uint8)
A = uint8(readmatrix(fullfile(dataDir, "thermal_frame_A.csv"), "CommentStyle", "#"));
B = uint8(readmatrix(fullfile(dataDir, "thermal_frame_B.csv"), "CommentStyle", "#"));

result = prodserver.mcp.call(endpoint, "blendImages", A, B, 0.6);

disp("Input type: " + class(A))
disp("Output type: " + class(result) + " (preserved!)")
disp("Output size: " + mat2str(size(result)))

figure
subplot(1,3,1)
imagesc(A)
title("Frame A")
colorbar

subplot(1,3,2)
imagesc(B)
title("Frame B")
colorbar

subplot(1,3,3)
imagesc(result)
title("Blended (alpha=0.6)")
colorbar

%[text] ### Gradient frames (int16, supports negative values)
A_grad = int16(readmatrix(fullfile(dataDir, "gradient_frame_A.csv"), "CommentStyle", "#"));
B_grad = int16(readmatrix(fullfile(dataDir, "gradient_frame_B.csv"), "CommentStyle", "#"));

result_grad = prodserver.mcp.call(endpoint, "blendImages", A_grad, B_grad, 0.7);

disp("Gradient input type: " + class(A_grad))
disp("Gradient output type: " + class(result_grad) + " (preserved!)")
disp("Value range: [" + min(result_grad(:)) + ", " + max(result_grad(:)) + "]")

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
