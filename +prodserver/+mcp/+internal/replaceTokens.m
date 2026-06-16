function config = replaceTokens(tokens,config)
%replaceTokens Replace all tokens in config with their values. config may
%be a string or a structure with string-valued fields.

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.validation.istext
    % Import yourself to be recursive.
    import prodserver.mcp.internal.replaceTokens
    
    if isstruct(config)
        fields = string(fieldnames(config)');
        for n = 1:numel(config)
            for f = fields
                config(n).(f) = replaceTokens(tokens, config(n).(f));
            end
        end
    elseif istext(config)
        names = string(keys(tokens));
        for n=1:numel(names)
            config = replace(config,names(n),tokens(names(n)));
        end
    end
end