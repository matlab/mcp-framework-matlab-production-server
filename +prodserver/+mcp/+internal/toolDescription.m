function desc = toolDescription(mf)
%toolDescription Compose tool-level description from metafunction data.
%   Combines Description and DetailedDescription into a single string
%   suitable for the MCP tool description field. Returns the function name
%   if no description is available.

% Copyright 2026 The MathWorks, Inc.

    d = strtrim(mf.Description);
    if isempty(mf.DetailedDescription)
        dd = {d};
    else
        dd = strtrim(split(mf.DetailedDescription, newline));
        dd = [{d}; dd];
    end

    % Handle empty or missing description
    if (iscell(dd) && isempty(dd{1})) || (isstring(dd) && strlength(dd) == 0)
        desc = string(mf.Name);
        return;
    end

    desc = strjoin(dd, " ");
end
