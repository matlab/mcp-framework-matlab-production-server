function m17 = magic17(quote)
% Generate a 17x17 magic square and print a pithy quote supplied by the
% caller.

% Copyright 2026 The MathWorks, Inc.

    arguments (Input)
        % Sophisticated and intelligent quote. (Sadly, unenforceable.)
        quote (1,1) string
    end
    arguments(Output)
        % 17x17 magic square.
        m17 (17,17) double
    end

    disp(quote);
    data = load("seventeen.mat");
    m17 = magic(data.x);
end