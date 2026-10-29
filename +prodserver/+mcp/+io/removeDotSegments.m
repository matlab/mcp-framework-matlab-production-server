function p = removeDotSegments(p)
%removeDotSegments Resolve . and .. in a path with / separators.
%   p = removeDotSegments(p) removes each . segment, and each .. segment
%   with the one before it, from string array P, element by element. ..
%   never climbs above the root: /, a drive (C:) or a UNC share
%   (//server/share). A relative path keeps the .. that climb above where
%   it starts: a/../../b is ../b.
%
%   File.FileURI2Path refuses a .. from a client. A local path may have
%   them, so code that builds a file: URI from one resolves them first, as
%   File.Path2FileURI does.

% Copyright 2026 The MathWorks, Inc.

    arguments
        p string
    end
    for n = 1:numel(p)
        p(n) = resolve(p(n));
    end
end

function p = resolve(p)
    parts = split(p, "/");
    if startsWith(p, "//")
        keep = min(4, numel(parts));      % "", "", server, share
    elseif startsWith(p, "/") || ~isempty(regexp(parts(1), "^[A-Za-z]:$", "once"))
        keep = 1;                         % "" or C:
    else
        keep = 0;                         % Relative
    end
    out = parts(1:keep);
    for k = keep+1:numel(parts)
        if parts(k) == "."
            continue
        elseif parts(k) == ".."
            if numel(out) > keep && out(end) ~= ".."
                out(end) = [];
            elseif keep == 0
                out(end+1) = ".."; %#ok<AGROW>   % Above where it starts
            end
        else
            out(end+1) = parts(k); %#ok<AGROW>
        end
    end
    if numel(out) == keep && keep == 1
        out(end+1) = "";                  % The root itself: / or C:/
    elseif isempty(out)
        out = ".";
    end
    p = strjoin(out, "/");
end
