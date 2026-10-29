function n = schemaTextCell(s, t, x, m, z)
% Count the elements of some text and cells.

% Copyright 2026 The MathWorks, Inc.

    arguments
        s (1,:) char        % A row of text
        t char              % Any char
        x (1,1) cell        % A cell
        m (2,3) char        % Two rows of three characters
        z (1,1) cell = {1}  % An optional cell
    end
    arguments (Output)
        n (1,1) double      % The total
    end
    n = numel(s) + numel(t) + numel(x) + numel(m) + numel(z);
end
