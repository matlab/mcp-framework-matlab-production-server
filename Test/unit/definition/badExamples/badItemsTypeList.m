function y = badItemsTypeList(x)
% Take numbers or nulls: a %#schema that lists types for an array's items.

% Copyright 2026 The MathWorks, Inc.
    arguments(Input)
        %#schema {"items": {"type": ["number", "null"]}}
        x (1,:) double    % Values.
    end
    arguments(Output)
        y (1,1) double    % One.
    end
    y = 1;
end
