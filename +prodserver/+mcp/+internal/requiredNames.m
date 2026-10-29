function names = requiredNames(x, member)
%requiredNames The names a JSON Schema lists as required.
%   NAMES = requiredNames(SCHEMA) returns the 'required' member of the
%   decoded JSON Schema SCHEMA as a 1xN string, in order.
%
%   NAMES = requiredNames(DEF, MEMBER) does the same for DEF.(MEMBER), where
%   DEF is a tool definition and MEMBER is "inputSchema" or "outputSchema".
%   A definition without that schema requires nothing.
%
%   A schema with no required names may omit the key altogether, or send
%   "required":[], which jsondecode turns into a 0x0 double (XD18); both
%   give an empty 1x0 string. The list is never split: it is already a list.
%   Anything else that is not text raises prodserver:mcp:InvalidSchema.
%
%   The one reader of 'required': the handler, the request builder, the
%   output assembler, argument validation and item counting all ask it, so
%   they cannot disagree about which properties a schema requires.

% Copyright 2026 The MathWorks, Inc.

    arguments
        x
        member (1,1) string {mustBeMember(member, ...
            ["", "inputSchema", "outputSchema"])} = ""
    end

    names = string.empty(1,0);

    schema = x;
    if strlength(member) > 0
        if ~prodserver.mcp.internal.hasField(x, member)
            return
        end
        schema = x.(member);
    end

    if ~isstruct(schema) || ~isfield(schema, 'required') || ...
            isempty(schema.required)
        return
    end

    required = schema.required;
    if ~(ischar(required) || isstring(required) || iscellstr(required))
        error("prodserver:mcp:InvalidSchema", ...
            "Property 'required' must be a string array or " + ...
            "convertible to a string array. Instead it has " + ...
            "incompatible type '%s'.", class(required));
    end
    names = string(required);
    names = names(:)';
end
