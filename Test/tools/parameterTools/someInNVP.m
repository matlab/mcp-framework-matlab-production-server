function [x,y,z] = someInNVP(a,b,opts)
% Three output, four input test function.
%
% Last two inputs optional. 
% Outputs are always optional in MATLAB.

% Copyright 2026-2026 The MathWorks, Inc.

    arguments(Input)
        a (1,1) double           % Required A
        b (1,1) double           % Required B
        opts.c (1,1) double = 4  % Optional C
        opts.d (1,1) double = 5  % Optional D
    end

    arguments(Output)
        x (1,1) double        % Value X
        y (1,1) double        % Value Y
        z (1,1) double        % Value Z
    end

    x = sum([a,b,opts.c,opts.d]);
    y = prod([a,b,opts.c,opts.d]);
    z = mean([a,b,opts.c,opts.d]);
end
