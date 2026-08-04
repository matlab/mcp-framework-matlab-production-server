classdef SchemaCallBy
% SchemaCallBy Explicit specification of parameter passing mode.

% Copyright 2026-2026 The MathWorks, Inc.

    enumeration
        Value,      % Pass parameter by value
        Reference   % Pass parameter by reference
    end

    properties (Constant)
        jsonKey = "x-call-by";
        fieldName = "x_call_by";
    end
end