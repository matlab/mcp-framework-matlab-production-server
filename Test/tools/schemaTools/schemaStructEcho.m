function y = schemaStructEcho(k)
% Return the K-th of some structs, with different fields or shapes, so that
% example calls that return two of them give an output with alternatives:
% (1) and (2) are struct arrays, with fields a, and a and b; (3) and (4)
% scalar structs with the same fields; (5) a struct whose field a is empty;
% (6) and (7) structs whose field a is Inf, and text.

% Copyright 2026 The MathWorks, Inc.

    values = {struct('a', {1, 2}), struct('a', {1, 2}, 'b', {3, 4}), ...
        struct('a', 1), struct('a', 1, 'b', 2), struct('a', []), ...
        struct('a', Inf), struct('a', "x")};
    y = values{k};
end
