function result = blendImages(A, B, alpha)
% Alpha-blend two images with type-dependent arithmetic.
%
% The pixel type determines the blending behavior:
%   uint8  -> 8-bit image, output clamped to [0, 255]
%   int16  -> Signed 16-bit, supports negative (difference images)
%   double -> HDR, no clamping, values may exceed [0, 1]
%
% Typical use cases include temporal noise reduction on thermal sensor
% arrays (e.g., Panasonic Grid-EYE AMG8833 at 8x8, or FLIR Lepton
% region-of-interest crops at 12x10) where averaging consecutive uint8
% frames reduces thermal noise while preserving output type for
% downstream threshold-based occupancy detection.
%
% Without wire encoding, JSON numbers carry no type. Both images arrive
% as double regardless of intent, always selecting the HDR code path.
% For uint8 data near saturation limits, this produces different values
% and a fundamentally different output type.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        A {mustBeNumeric}      % Image A (uint8, int16, or double)
        B {mustBeNumeric}      % Image B (same type as A)
        alpha (1,1) double     % Blending factor in [0, 1]
    end
    arguments(Output)
        result {mustBeNumeric} % Blended image (same type as A)
    end

    outClass = class(A);

    switch outClass
        case 'uint8'
            result = uint8(alpha * double(A) + (1 - alpha) * double(B));
        case 'int16'
            result = int16(alpha * double(A) + (1 - alpha) * double(B));
        case 'double'
            result = alpha * A + (1 - alpha) * B;
        otherwise
            error('blendImages:unsupportedType', ...
                'Unsupported pixel type: %s. Use uint8, int16, or double.', outClass);
    end

end
