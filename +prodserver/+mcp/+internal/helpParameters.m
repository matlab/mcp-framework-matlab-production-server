function params = helpParameters(mf)
%helpParameters Parameter descriptions written in a function's help text.
%   params = helpParameters(mf) finds lines of the help text that describe
%   one of the function's inputs or outputs, in the usual MATLAB styles:
%
%       % signal: samples to smooth
%       %   windowSize - window length,
%       %       in samples
%
%   The line must begin with the parameter's name, compared without regard
%   to case (help text often writes N or VECTORS), then : or - and the
%   description. A following line indented more deeply continues it. A
%   line that begins with any other word, such as "type: ...", is not a
%   parameter line.
%
%   params is a struct array with fields name (as declared), text (the
%   description) and lines (indices into the lines of
%   mf.DetailedDescription). Only the first line for each parameter
%   counts.
%
%See also: toolDescription, parameterDescription

% Copyright 2026 The MathWorks, Inc.

    params = struct("name", {}, "text", {}, "lines", {});
    if isempty(mf.DetailedDescription)
        return
    end

    names = string.empty;
    if ~isempty(mf.Signature.Inputs)
        names = [names, arrayfun(@(p) string(p.Identifier.Name), ...
            mf.Signature.Inputs)];
    end
    if ~isempty(mf.Signature.Outputs)
        names = [names, arrayfun(@(p) string(p.Identifier.Name), ...
            mf.Signature.Outputs)];
    end
    if isempty(names)
        return
    end

    lines = split(string(mf.DetailedDescription), newline);
    found = strings(0);
    k = 1;
    while k <= numel(lines)
        [name, tok] = parameterLine(lines(k), names);
        if name == "" || ismember(name, found)
            k = k + 1;
            continue
        end

        indent = strlength(tok(1));
        text = strtrim(tok(3));
        used = k;
        k = k + 1;
        % Continuation: non-blank, indented more deeply, and not another
        % parameter's line.
        while k <= numel(lines) && strlength(strtrim(lines(k))) > 0 && ...
                strlength(lines(k)) - strlength(strip(lines(k), "left")) > indent && ...
                parameterLine(lines(k), names) == ""
            text = text + " " + strtrim(lines(k));
            used(end+1) = k; %#ok<AGROW>
            k = k + 1;
        end

        found(end+1) = name; %#ok<AGROW>
        params(end+1) = struct("name", name, "text", text, "lines", used); %#ok<AGROW>
    end
end

function [name, tok] = parameterLine(line, names)
% The parameter a help line describes, or "" if it describes none. tok
% holds the indent, the word and the description.
    name = "";
    tok = regexp(line, "^(\s*)([A-Za-z]\w*)\s*(?::|--?)\s+(\S.*)$", ...
        "tokens", "once");
    if ~isempty(tok)
        name = matchName(tok(2), names);
    end
end

function name = matchName(word, names)
% The declared name word refers to: an exact match, else the only match
% without regard to case. x and X are distinct parameters, so a word that
% matches both only by case matches neither.
    if ismember(word, names)
        name = word;
        return
    end
    m = names(strcmpi(names, word));
    if isscalar(m)
        name = m;
    else
        name = "";
    end
end
