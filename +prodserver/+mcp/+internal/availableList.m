function txt = availableList(what, names)
%availableList What a server has, for an error that it hasn't the one asked
%   for: "Its tools are: a, b, c." for WHAT "tools", or "It has no tools."
%   The first few of NAMES, sorted, then how many more, so a server with
%   many doesn't fill the Command Window.

% Copyright 2026 The MathWorks, Inc.

    arguments
        what (1,1) string
        names string
    end

    names = unique(names(:)');
    if isempty(names)
        txt = "It has no " + what + ".";
        return
    end
    shown = min(numel(names), 10);
    txt = "Its " + what + " are: " + strjoin(names(1:shown), ", ");
    if numel(names) > shown
        txt = txt + ", and " + (numel(names) - shown) + " more";
    end
    txt = txt + ".";
end
