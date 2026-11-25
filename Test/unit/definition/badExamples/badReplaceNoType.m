function t = badReplaceNoType(x)
% Test example for a replacing schema with no type.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        %#schema ={"oneOf": [{"type": "number"}, {"type": "array", "items": {"type": "number"}}]}
        x (1,:) double    % The input.
    end
    arguments(Output)
        t double    % The output.
    end

    t = x;
end
