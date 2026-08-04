function value = loadmatrix(name, matFile, varargin)
%loadmatrix Load a variable from a MAT-file and return the value.

% Copyright 2025-2026 The MathWorks, Inc.

    v = load(matFile, name, varargin{:});
    value = v.(name);
end
