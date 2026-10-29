function [t, d1, dn] = schemaWireOutputs(n)
% Return classes only the invertible encoding carries.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        n (1,1) double          % Rows
    end
    arguments(Output)
        t table                 % A table
        d1 (1,1) datetime       % One datetime
        dn (1,:) datetime       % Some datetimes
    end

    t = table((1:n)', VariableNames="id");
    d1 = datetime(2026,1,2);
    dn = datetime(2026,1,1:n);
end
