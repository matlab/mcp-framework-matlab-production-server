function y = schemaConflict(x)
% A function with a conflicting schema annotation (scalar + maxItems).

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        % Input value.
        %#schema +{ "maxItems": 10 }
        x (1,1) double
    end

    arguments(Output)
        y (1,1) double   % Doubled value
    end

    y = x * 2;
end
