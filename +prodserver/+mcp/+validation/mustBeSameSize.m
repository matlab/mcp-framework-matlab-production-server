function mustBeSameSize(reference,items)
% mustBeSameSize All the function arguments in items (a subset) must be 
% the same size as the argument in the reference position (which is a
% position in the original, full, set of arguments).

% Copyright 2025, The MathWorks, Inc.

    arguments
        reference double
    end
    arguments (Repeating)
        items 
    end

    sz = size(items{1});
    for i = 2:numel(items)
        if any(sz ~= size(items{i}))
            error("prodserver:mcp:DifferentSize", ...
                "Argument at position %d must be the same size as " + ...
                "argument at position %d.", i-1+reference, reference);
        end
    end
end