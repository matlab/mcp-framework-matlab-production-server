function a = heroArea(x,y,z)
% heroArea Compute triangle area using Hero's formula.

% Copyright 2025, The MathWorks, Inc.
    arguments(Input)
        x (1,1) double
        y (1,1) double
        z (1,1) double
    end

    % Semi-perimeter: add side lengths and divide by 2
    s = (x + y + z) ./ 2;

    % Hero's formula
    a = sqrt(s * (s-x) * (s-y) * (s-z));
end
