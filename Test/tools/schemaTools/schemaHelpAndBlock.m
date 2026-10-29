function y = schemaHelpAndBlock(a, b)
% Add two numbers.
% a: the first number, from the help text
% b: the second number, from the help text

% Copyright 2026 The MathWorks, Inc.

    arguments
        a (1,1) double   % First addend
        b (1,1) double
    end
    arguments (Output)
        y (1,1) double   % Sum
    end
    y = a + b;
end
