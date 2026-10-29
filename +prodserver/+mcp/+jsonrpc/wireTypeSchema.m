function schema = wireTypeSchema(matlabClass, shape)
%wireTypeSchema JSON schema of a value only the invertible encoding carries.
%   schema = wireTypeSchema(matlabClass, shape) returns the schema of an
%   invertibly encoded datetime, duration, categorical, table or timetable.
%   shape is a WireShape, because a scalar datetime or duration has a
%   different encoding from an array of them. The other classes ignore
%   shape.
%
%   The forms follow wire_encoding_rules.txt. The required fields are the
%   ones mcpWireDecodeValue needs. Unlike the generic wrapper in
%   wireEncodingArgTemplate.json, this is the whole encoded value, not the
%   data of a wrapper.

% Copyright 2026 The MathWorks, Inc.

    arguments
        matlabClass (1,1) string
        shape (1,1) prodserver.mcp.jsonrpc.WireShape = ...
            prodserver.mcp.jsonrpc.WireShape.Either
    end
    % Here, not in the arguments block, which can't name a constant.
    mustBeMember(matlabClass, [prodserver.mcp.internal.Constants.ConvertedClasses, ...
        prodserver.mcp.internal.Constants.InvertibleClasses]);

    switch matlabClass
        case "datetime"
            % A scalar is a bare ISO 8601 string -- or, in a named time
            % zone, the wrapper, whose tz names it. So the scalar and
            % either-shape schemas are the same.
            array = wrapped("datetime", struct('type', "string"));
            array.properties.tz = struct('type', "string");
            % Bare text is ISO 8601, or NaT.
            text = struct('type', "string", 'format', ...
                prodserver.mcp.MCPConstants.DateTimeFormat);
            nat = struct('type', "string", 'enum', ...
                {{prodserver.mcp.MCPConstants.NaTText}});
            if shape == prodserver.mcp.jsonrpc.WireShape.Array
                schema = array;
            else
                schema = struct('anyOf', {{text, nat, array}});
            end
        case "duration"
            scalar.type = "object";
            scalar.required = ["type", "seconds"];
            scalar.properties.type = classTag("duration");
            scalar.properties.seconds = struct('type', "number");
            array = wrapped("duration", struct('type', "number"));
            schema = byShape(shape, scalar, array);
        case "categorical"
            % Undefined elements are null.
            schema = wrapped("categorical", struct('type', {{"string", "null"}}));
            schema.properties.categories = struct('type', "array", ...
                'items', struct('type', "string"));
            schema.properties.ordinal = struct('type', "boolean");
        case "table"
            schema = tabular("table");
        case "timetable"
            schema = tabular("timetable");
    end
end

function s = wrapped(matlabClass, element)
% The type, size and data wrapper the rules use for arrays.
    s.type = "object";
    s.required = ["type", "size", "data"];
    s.properties.type = classTag(matlabClass);
    s.properties.size = struct('type', "array", ...
        'items', struct('type', "number"), 'minItems', 2);
    s.properties.data = struct('type', "array", 'items', element);
end

function s = tabular(matlabClass)
% A table or timetable: one encoded value per variable.
    variable.type = "object";
    variable.required = ["name", "value"];
    variable.properties.name = struct('type', "string");
    variable.properties.value = struct();   % Any encoded value

    s.type = "object";
    if matlabClass == "table"
        s.required = ["type", "variables"];
    else
        s.required = ["type", "rowTimes", "variables"];
    end
    s.properties.type = classTag(matlabClass);
    s.properties.rows = struct('type', "integer");
    if matlabClass == "table"
        s.properties.rowNames = struct('type', "array", ...
            'items', struct('type', "string"));
    else
        % Encoded datetimes or durations, of either shape.
        dt = prodserver.mcp.jsonrpc.wireTypeSchema("datetime");
        du = prodserver.mcp.jsonrpc.wireTypeSchema("duration");
        s.properties.rowTimes = struct('anyOf', {[dt.anyOf, du.anyOf]});
        s.properties.timeName = struct('type', "string");
    end
    s.properties.variables = struct('type', "array", 'items', variable);
end

function tag = classTag(matlabClass)
% The schema of a type field that must be MATLABCLASS. A one-element enum,
% not const, which not every LLM provider's tool schemas support.
    tag = struct('enum', {{string(matlabClass)}});
end

function s = byShape(shape, scalar, array)
    switch shape
        case prodserver.mcp.jsonrpc.WireShape.Scalar
            s = scalar;
        case prodserver.mcp.jsonrpc.WireShape.Array
            s = array;
        otherwise
            s = struct('anyOf', {{scalar, array}});
    end
end
