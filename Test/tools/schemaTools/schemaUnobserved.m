function [a, b] = schemaUnobserved(x, y)
% Scale x by y and describe the result.

% Copyright 2026 The MathWorks, Inc.

    arguments
        x (1,1) double   % Value
        y (1,1) double = 1  % Scale
    end
    arguments (Output)
        a (1,1) double   % Scaled value
        b (1,1) string   % Description
    end
    a = x * y;
    b = "scaled by " + y;
end
