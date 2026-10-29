function s = toyPositiveTwo(a, b)
%toyPositiveTwo Add two positive numbers. The constraints are ones MATLAB
%enforces but the schema can't express, so a bad value reaches the tool.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        a (1,1) double {mustBePositive}  % First addend
        b (1,1) double {mustBePositive}  % Second addend
    end
    arguments(Output)
        s (1,1) double                   % Sum
    end

    s = a + b;
end
