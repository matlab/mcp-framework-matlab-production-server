function schema = jsonTimeSchema(matlabClass, shape, count)
%jsonTimeSchema Plain JSON schema of a datetime or duration value.
%   schema = jsonTimeSchema(matlabClass, shape) returns the schema of a
%   datetime or duration under plain JSON encoding:
%
%     datetime  ISO 8601 text: {"type":["string","null"],"format":"date-time"}
%     duration  Seconds:       {"type":["number","null"],"x-matlab-class":"duration"}
%
%   null is NaT, or a duration of NaN seconds. shape is a WireShape. An
%   array, or a value that may be one, is an array of these; a scalar
%   satisfies it too, as MATLAB scalars are 1x1 arrays.
%
%   schema = jsonTimeSchema(matlabClass, shape, count) adds minItems and
%   maxItems to an array schema of exactly COUNT elements.
%
%   plainJSONValue writes these forms; decodeJSONValues reads them.

% Copyright 2026 The MathWorks, Inc.

    arguments
        matlabClass (1,1) string
        shape (1,1) prodserver.mcp.jsonrpc.WireShape = ...
            prodserver.mcp.jsonrpc.WireShape.Either
        count double = []
    end

    import prodserver.mcp.MCPConstants

    % Here, not in the arguments block, which can't name a constant.
    mustBeMember(matlabClass, prodserver.mcp.internal.Constants.ConvertedClasses);

    if matlabClass == "datetime"
        element = struct('type', {{"string"; "null"}}, 'format', ...
            MCPConstants.DateTimeFormat);
    else
        element = struct('type', {{"number"; "null"}});
        element.(MCPConstants.MatlabClass_Field) = "duration";
    end

    if shape == prodserver.mcp.jsonrpc.WireShape.Scalar
        schema = element;
    else
        schema = struct('type', "array", 'items', element);
        if isscalar(count) && isfinite(count) && count > 1
            schema.minItems = count;
            schema.maxItems = count;
        end
    end
end
