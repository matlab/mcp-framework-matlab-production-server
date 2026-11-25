function y = badKeywordSchema(x)
% Test example for a length the server can't check.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        % null is no length: every call raised an error.
        %#schema { "maxLength": null }
        x (1,1) string    % Some text.
    end
    arguments(Output)
        y (1,1) string    % The same text.
    end

    y = x;
end
