function [x,y,z] = allIndirect(a,b,c,d)
% Thee output, four input test function.
%
% All inputs and outputs indirect. All inputs required.
% Outputs are always optional in MATLAB.

% Copyright 2026, The MathWorks, Inc.

    % Explicitly specify call by reference to make scalar parameters
    % indirect.

    arguments(Input)
        %#schema { "x-call-by": "reference" }
        a double      % Required A
        %#schema { "x-call-by": "reference" }
        b double      % Required B
        %#schema { "x-call-by": "reference" }
        c double      % Required C
        %#schema { "x-call-by": "reference" }
        d double      % Required D
    end

    arguments(Output)
        x double      % Value X
        y double      % Value Y
        z double      % Value Z
    end

    x = sum([a,b,c,d]);
    y = prod([a,b,c,d]);
    z = mean([a,b,c,d]);
end
