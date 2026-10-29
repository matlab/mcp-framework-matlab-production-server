function desc = toolDescription(mf, opts)
%toolDescription Compose tool-level description from metafunction data.
%   Combines Description and DetailedDescription into a single string
%   suitable for the MCP tool description field. Returns the function name
%   if no description is available.
%
%   desc = toolDescription(mf, exclude=names) leaves out the help-text
%   lines that describe the parameters in names (see helpParameters), for
%   parameters whose description they have become.

% Copyright 2026 The MathWorks, Inc.

    arguments
        mf
        opts.exclude string = string.empty
    end

    d = strtrim(mf.Description);
    if isempty(mf.DetailedDescription)
        dd = {d};
    else
        lines = split(string(mf.DetailedDescription), newline);
        if ~isempty(opts.exclude)
            params = prodserver.mcp.internal.helpParameters(mf);
            params = params(ismember([params.name], opts.exclude));
            lines([params.lines]) = [];
        end
        dd = [{d}; cellstr(strtrim(lines))];
    end

    % Handle empty or missing description
    if (iscell(dd) && isempty(dd{1})) || (isstring(dd) && strlength(dd) == 0)
        desc = string(mf.Name);
        return;
    end

    desc = strjoin(dd, " ");
    if ~isempty(opts.exclude)
        % Removed lines can leave a trailing space.
        desc = strtrim(desc);
    end
end
