function y = toyEmptyOutput(n)
% Return N ones, under an output schema of one number: none for 0.

% Copyright 2026 The MathWorks, Inc.
    arguments (Input)
        n (1,1) double       % How many ones.
    end
    arguments (Output)
        %#schema ={"type": "number"}
        y double             % The ones.
    end
    y = ones(1, n);
end
