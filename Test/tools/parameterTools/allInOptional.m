function [x,y,z] = allInOptional(a,b,c,d)
% Thee output, four input test function.
%
% All inputs optional. 
% Outputs are always optional in MATLAB.

% Copyright 2026-2026 The MathWorks, Inc.

    arguments(Input)
        a (1,1) double = 2    % Optional A
        b (1,1) double = 3    % Optional B
        c (1,1) double = 4    % Optional C
        d (1,1) double = 5    % Optional D
    end

    arguments(Output)
        x (1,1) double        % Value X
        y (1,1) double        % Value Y
        z (1,1) double        % Value Z
    end

    x = sum([a,b,c,d]);
    y = prod([a,b,c,d]);
    z = mean([a,b,c,d]);
end
