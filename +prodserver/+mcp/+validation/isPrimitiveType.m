function tf = isPrimitiveType(x)
% isPrimitiveType True if X is a non-container MATLAB type. 

% Copyright 2026, The MathWorks, Inc.

    tf = false(size(x));
    if prodserver.mcp.validation.istext(x)
        tf = ismember(x,prodserver.mcp.internal.Constants.primitiveType);
    end
end