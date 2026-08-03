function jsonType = jsonParameterType(matlabType,typemap)
% Map MATLAB types to JSON RPC types. The only valid types for JSON are:
% array, boolean, integer, null, number, object, string. In this list,
% "object" means struct.
% 
% Return a "" string if there is no compatible JSON type.

% Copyright 2026 The MathWorks, Inc.

    arguments
        matlabType string
        typemap struct
    end
    
    intType = textBoundary("start") + ("int" | "uint") + ...
        ("8" | "16" | "32" | "64" | "128") + textBoundary("end");
    
    jsonType = strings(1,numel(matlabType));
    
    for n = 1:numel(matlabType)
    
        % Special case types first -- user specified these conversions, so
        % honor them.
        if ismember(matlabType(n),fieldnames(typemap))
            jsonType(n) = typemap.(matlabType(n));
            % Character types become string
        elseif strcmp(matlabType(n),"char") || strcmp(matlabType(n),"string")
            jsonType(n) = "string";
    
            % All integer types become "integer"
        elseif matches(matlabType(n),intType)
            jsonType(n) = "integer";
    
            % Floating point types are "number"
        elseif strcmp(matlabType(n),"double") || strcmp(matlabType(n),"float")
            jsonType(n) = "number";
    
            % Data with named fields is an "object"
        elseif strcmp(matlabType(n),"struct")
            jsonType(n) = "object";
    
            % logical -> boolean
        elseif strcmp(matlabType(n),"logical")
            jsonType(n) = "boolean";
    
            % cell arrays are JSON arrays
        elseif strcmp(matlabType(n),"cell")
            jsonType(n) = "array";
    
            % No compatible JSON type for this MATLAB type. 
        else
            jsonType(n) = "";
        end
    end
end