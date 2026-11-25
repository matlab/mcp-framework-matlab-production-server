function t = badAddTypeList(x)
% Test example for an added schema that replaces the type with a list.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        %#schema {"type": ["number", "null"]}
        x (1,1) double    % The input.
    end
    arguments(Output)
        t double    % The output.
    end

    t = x;
end
