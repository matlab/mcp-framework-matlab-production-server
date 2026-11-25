function y = schemaWireEcho(k)
% Return the K-th of some values that hold Inf or -Inf, from a finite
% argument, so that only the output does, or (from 6) a value of another
% class, to mix with them.

% Copyright 2026 The MathWorks, Inc.

    values = {Inf, single(-Inf), [1 -Inf], struct('a', 1, 'z', -Inf), ...
        {1, Inf}, 'none', "none", [1 2], ["a" "b"]};
    y = values{k};
end
