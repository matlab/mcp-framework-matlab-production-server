function t = toyTotal(x)
% Total a number, or an array of numbers, which a oneOf allows.

% Copyright 2026 The MathWorks, Inc.
    arguments(Input)
        %#schema {"oneOf": [{"type": "number"}, {"type": "array", "items": {"type": "number"}}]}
        x (1,:) double    % A number, or the numbers to total.
    end
    arguments(Output)
        t (1,1) double    % The total.
    end
    t = sum(x);
end
