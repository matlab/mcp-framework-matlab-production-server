function v = plainJSONValue(v)
%plainJSONValue Prepare a tool output for plain JSON encoding.
%   v = plainJSONValue(v) replaces the values jsonencode would write as
%   display text, which depends on the server's locale and settings, with
%   values a client can parse anywhere:
%
%     datetime   ISO 8601 text, as the invertible encoding writes a scalar
%                datetime: 2026-01-02T03:04:05.000 when unzoned, with a Z
%                suffix in UTC, with an offset in any other zone. An
%                array in a zone other than UTC is written in UTC: a named
%                zone's offset changes with daylight saving, and an array
%                must have one zone to be read back. NaT becomes null.
%     duration   Its length in seconds.
%     timetable  A table, with the row times as its first variable.
%                (jsonencode writes a timetable as {}.)
%
%   It looks inside structs, struct arrays, cells and tables. Other values
%   are unchanged. Only plain JSON encoding needs this: the invertible
%   encoding has its own forms for these classes.

% Copyright 2026 The MathWorks, Inc.

    if isa(v, "datetime")
        if ~isscalar(v) && ~isempty(v.TimeZone)
            v.TimeZone = "UTC";
        end
        v = prodserver.mcp.jsonrpc.isoDateTimeText(v);
    elseif isa(v, "duration")
        v = seconds(v);
    elseif istimetable(v)
        v = prodserver.mcp.jsonrpc.plainJSONValue(timetable2table(v));
    elseif istable(v)
        for name = string(v.Properties.VariableNames)
            v.(name) = prodserver.mcp.jsonrpc.plainJSONValue(v.(name));
        end
    elseif isstruct(v)
        for k = 1:numel(v)
            for f = string(fieldnames(v))'
                v(k).(f) = prodserver.mcp.jsonrpc.plainJSONValue(v(k).(f));
            end
        end
    elseif iscell(v)
        v = cellfun(@prodserver.mcp.jsonrpc.plainJSONValue, v, ...
            UniformOutput=false);
    end
end
