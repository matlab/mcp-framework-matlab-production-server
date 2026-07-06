function tf = isJsonSchemaType(x)
% isJsonSchemaType Is X a known JSON schema type?

% Copyright 2026, The MathWorks, Inc.

    tf = false;
    if isstring(x) || ischar(x)
        jType = ["array","object","number","integer","boolean","null", ...
            "string"];
        tf = ismember(x,jType);
    end
end
