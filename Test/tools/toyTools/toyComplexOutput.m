function y = toyComplexOutput(x)
%toyComplexOutput Test function whose output is complex for some inputs:
%the square root of its input. Real for x >= 0, complex for x < 0, which
%nothing in its declaration can say.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        x (1,1) double  % A scalar double.
    end
    arguments(Output)
        y (1,1) double  % The square root of x.
    end

    y = sqrt(x);

end
