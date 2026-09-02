function [x,y,z] = threeFour(a,b,c,d)
% Thee output, four input test function.
%
% All inputs required. 
% Outputs are always optional in MATLAB.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        a (1,1) double      % Required A
        b (1,1) double      % Required B
        c (1,1) double      % Required C
        d (1,1) double      % Required D
    end

    arguments(Output)
        x (1,1) double      % Value X
        y (1,1) double      % Value Y
        z (1,1) double      % Value Z
    end

    x = sum([a,b,c,d]);
    y = prod([a,b,c,d]);
    z = mean([a,b,c,d]);
end
