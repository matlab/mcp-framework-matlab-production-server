function n = schemaStructColumn(materials)
% Count the materials in a list.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        materials (:,1) struct     % Material properties
    end
    arguments(Output)
        n (1,1) double             % Number of materials
    end

    n = numel(materials);
end
