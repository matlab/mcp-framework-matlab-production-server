function y = schemaWireHandle(f)
% Apply a function handle.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        f function_handle    % Function to apply
    end
    arguments(Output)
        y (1,1) double       % Result
    end

    y = f(2);
end
