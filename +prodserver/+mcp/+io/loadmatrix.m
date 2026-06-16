function value = loadmatrix(name, matFile, varargin)
%loadmatrix Load a variable from a MAT-file and return the value.

% Copyright (C) 2022, The MathWorks, Inc.

    v = load(matFile, name, varargin{:});
    value = v.(name);
end
