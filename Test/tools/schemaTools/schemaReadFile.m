function [total, nRows, nCols] = schemaReadFile(filename)
%schemaReadFile Read a CSV file and return summary statistics.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        filename (1,1) string
    end
    arguments(Output)
        total (1,1) double
        nRows (1,1) double
        nCols (1,1) double
    end

    data = readmatrix(filename);
    total = sum(data, "all");
    [nRows, nCols] = size(data);
end
