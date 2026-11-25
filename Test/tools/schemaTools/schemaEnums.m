function r = schemaEnums(level, flag, mode, pair, counts)
% Accept arguments whose %#schema lists an enum, examples, a default or a
% const that jsondecode would not keep as an array.

% Copyright 2026 The MathWorks, Inc.
    arguments(Input)
        %#schema {"enum": [1, 2, 3]}
        level (1,1) double    % Numeric enum.
        %#schema {"enum": [true]}
        flag (1,1) logical    % One-member boolean enum.
        %#schema {"enum": ["fast", "slow"], "default": "fast"}
        mode (1,1) string     % String enum.
        %#schema {"enum": [[1, 2], [3, 4]], "examples": [[1, 2]]}
        pair (1,2) double     % Enum of arrays.
        %#schema {"default": [5], "examples": [[5], [6, 7]]}
        counts (1,:) double   % Array default and examples.
    end
    arguments(Output)
        %#schema {"const": [1]}
        r (1,:) double        % Array const.
    end
    r = 1;
end
