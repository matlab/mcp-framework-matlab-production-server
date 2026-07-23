function [x,y,z] = oneIndirectOutput(a,b,c,d)
% Thee output, four input test function.
%
% All inputs required. 
% Outputs are always optional in MATLAB.
% One output indirect.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        a (1,1) double   % Required A
        b (1,1) double   % Required B
        c (1,1) double   % Required C
        d (1,1) double   % Required D
    end

    arguments(Output)
        x (1,1) double   % Value X
        %#schema { "x-call-by": "reference" }
        y (1,1) double   % Reference Y
        z (1,1) double   % Value Z
    end

    x = sum([a,b,c,d]);
    y = prod([a,b,c,d]);
    z = mean([a,b,c,d]);
end
