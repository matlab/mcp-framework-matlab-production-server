function [z, mag, phase] = schemaComplexNoBlock(realPart, imagPart)
% Combine real and imaginary parts into complex numbers.

% Copyright 2026 The MathWorks, Inc.

    z = complex(realPart, imagPart);
    mag = abs(z);
    phase = angle(z);
end
