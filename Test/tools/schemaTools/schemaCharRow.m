function n = schemaCharRow(label)
% Measure a label.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        label (1,:) char           % Label text
    end
    arguments(Output)
        n (1,1) double             % Number of characters
    end

    n = numel(label);
end
