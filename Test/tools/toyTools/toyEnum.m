function y = toyEnum(level)
% Return the level, which a numeric enum limits to 1, 2 or 3.

% Copyright 2026 The MathWorks, Inc.
    arguments(Input)
        %#schema {"enum": [1, 2, 3]}
        level (1,1) double    % The level: 1, 2 or 3.
    end
    arguments(Output)
        y (1,1) double        % The level.
    end
    y = level;
end
