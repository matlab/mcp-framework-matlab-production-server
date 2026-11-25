function r = schemaBounds(lower, upper, both, many)
% Accept arguments whose %#schema bounds a scalar, or requires at least
% three elements of a vector.

% Copyright 2026 The MathWorks, Inc.
    arguments(Input)
        %#schema {"minimum": 0}
        lower (1,1) double    % At least 0.
        %#schema {"maximum": 10}
        upper (1,1) double    % At most 10.
        %#schema {"minimum": 0, "maximum": 10}
        both (1,1) double     % From 0 to 10.
        %#schema {"minItems": 3}
        many (1,:) double     % At least three numbers.
    end
    arguments(Output)
        r (1,1) double        % The sum.
    end
    r = lower + upper + both + sum(many);
end
