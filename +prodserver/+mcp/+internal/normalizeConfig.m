function c = normalizeConfig(config)
%normalizeConfig Change all field names to lowercase and all
%character vectors to strings.

% Copyright 2025, The MathWorks, Inc.

    c = prodserver.mcp.internal.stringify(config);
    c = lowercaseFieldNames(c);
end

function s = lowercaseFieldNames(s)
    if isstruct(s)
        if isscalar(s)
            fields = string(fieldnames(s));
            for f = 1:numel(fields)
                name = fields(f);
                lc = lower(name);
                s0.(lc) = lowercaseFieldNames(s.(name));
            end
        else
            for n = 1:numel(s)
                s0(n) = lowercaseFieldNames(s(n));
            end
        end
        s = s0;
    end
end
