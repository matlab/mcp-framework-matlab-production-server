function j = mcpWireEncode(value)
%mcpWireEncode  Encode a MATLAB value as an MCP JSON-compatible structure.
%
%   J = mcpWireEncode(VALUE) encodes VALUE into a MATLAB struct/cell/scalar
%   and then serializes that to JSON with jsonencode(J) to produce the MCP
%   wire encoding (spec v1.1).
%
%   Encoding summary
%   ----------------
%   Scalars                  Bare JSON primitives (no wrapper)
%   Numeric/logical arrays   {"type","size","data"} — data row-major
%   char row vector          Bare string
%   char matrix (M>1)        {"type":"char","size","data"} — row-major chars
%   string array             {"type":"string","size","data"}
%   scalar struct            Plain JSON object, fields encoded recursively
%   struct array             {"type":"struct","size","data"}
%   cell array               {"type":"cell","size","data"}
%   datetime scalar          Bare ISO 8601 string
%   datetime array           {"type":"datetime","size","data"}
%   duration scalar          {"type":"duration","seconds":s}
%   duration array           {"type":"duration","size","data"}
%   categorical              {"type":"categorical","size","categories","data"}
%   table                    {"type":"table","rows","variables":[...]}
%   timetable                {"type":"timetable","rows","rowTimes","variables":[...]}
%
%   Error IDs all use the prefix  prodserver:mcp
%
%   See also: mcpWireEncodeValue, mcpWireDecode, jsonencode

% Copyright 2026-2026 The MathWorks, Inc.

    j = prodserver.mcp.jsonrpc.mcpWireEncodeValue(value);
    j = jsonencode(j);
end
