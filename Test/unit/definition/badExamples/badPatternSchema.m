function y = badPatternSchema(x)
% Test example for a pattern the server can't check.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        % MATLAB's regexp doesn't support \p{L}: it would match nothing.
        %#schema { "pattern": "^\\p{L}+$" }
        x (1,1) string    % Letters only.
    end
    arguments(Output)
        y (1,1) string    % The same letters.
    end

    y = x;
end
