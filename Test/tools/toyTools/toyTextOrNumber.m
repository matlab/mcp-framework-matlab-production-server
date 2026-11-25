function y = toyTextOrNumber(kind)
% Return text, a number or -Inf, by KIND, under an output schema that
% allows text or a number: -Inf's text would read back as text.

% Copyright 2026 The MathWorks, Inc.
    arguments (Input)
        kind (1,1) string    % "text", "number" or "inf".
    end
    arguments (Output)
        %#schema ={"anyOf": [{"type": "string"}, {"type": ["number", "null", "string"], "pattern": "^-?Inf$"}]}
        y                    % The value.
    end
    switch kind
        case "text"
            y = "none";
        case "number"
            y = 5;
        otherwise
            y = -Inf;
    end
end
