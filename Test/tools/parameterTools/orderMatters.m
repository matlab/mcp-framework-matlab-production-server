function [x,y,z] = orderMatters(a,b,c,d)
% orderMatters Order of arguments changes the result.

% Copyright 2026 The MathWorks, Inc

    % Note: these comments would be more meaningful if the inputs were less
    % arbitrary. 

    arguments (Input)
        a (1,1) double  % An aribitrary number
        b (1,1) double  % Choose your own adventure
        c (1,1) double  % Another number. Don't pick a boring one.
        d (1,1) double  % Last but highest impact.
    end
    arguments(Output)
        x (1,1) double  % (a-b) / (c-d)
        y (1,1) double  % mod(b,c)
        z (1,1) double  % a .^ d
    end
    
    x = (a - b) / (c - d);
    y = mod(b, c);
    z = a .^ d;
end