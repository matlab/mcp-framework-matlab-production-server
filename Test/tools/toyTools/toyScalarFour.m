function x = toyScalarFour(a,c,m,x0)
%toyScalarFour Linear Congruential Generator of random numbers.

% Copyright 2026, The MathWorks, Inc.

    arguments(Input)
        a (1,1) double { mustBeInteger }   % Multiplier 
        c (1,1) double { mustBeInteger }   % Constant
        m (1,1) double { mustBeInteger }   % Modulus
        x0 (1,1) double { mustBeInteger }  % Initial value
    end
    arguments(Output)
        x (1,1) double  % Random-ish number.
    end

    x = mod((a * x0) + c,m);
end


    
