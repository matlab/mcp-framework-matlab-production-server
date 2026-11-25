function t = badReplaceTypeList(x)
% Test example for a replacing schema with a list of types.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        %#schema ={"type": ["number", "null"]}
        x double    % The input.
    end
    arguments(Output)
        t double    % The output.
    end

    t = x;
end
