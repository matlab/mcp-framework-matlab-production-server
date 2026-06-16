function uri = normalizeURI(uri)
%normalizeURI Ensure all URIs have a consistent format.
%
% Accept a variety of URI representations: text, parsed into a structure or
% a dictionary mapping names to URIs.
%
% Do not modify or complain about empty URIs.

% Copyright (c) 2024, The MathWorks, Inc.

    import prodserver.mcp.validation.istext

    if isempty(uri)
        return;
    end

    if istext(uri)
        uri = normalizePath(uri);
    elseif isa(uri,"dictionary")
        x = keys(uri)';
        uri(x) = normalizePath(uri(x));
    elseif isstruct(uri)
        np = num2cell(normalizePath([uri.path]));
        [uri.path] = np{:};
        np = num2cell(normalizePath([uri.uri]));
        [uri.uri] = np{:};
    end
end

function np = normalizePath(p)
% Normalize only the path part of the URI. Do not modify query parameters.
%
%  * Convert all \ to /
%  * Collapse // to / except in scheme authority :// and UNC prefix //

    import prodserver.mcp.internal.Constants

    hasParams = contains(p,Constants.ParamStart);
    pth = p;
    param = repmat("",size(p));
    if any(hasParams)
        pth(hasParams) = extractBefore(p(hasParams),Constants.ParamStart);
        param(hasParams) = extractAfter(p(hasParams),pth(hasParams));
    end

    pth = strrep(pth,"\","/");
    pth = collapseSlashes(pth);
    np = pth + param;
end

function pth = collapseSlashes(pth)
% Collapse runs of slashes to a single slash, preserving scheme authority
% :// and UNC leading //.

    AT = string(char(1));
    UT = string(char(2));

    persistent uncAtStart uncAfterAuth
    if isempty(uncAtStart)
        % Match // followed by a server name, not a drive letter like //C:
        uncSuffix = wildcardPattern(1) + ...
            (textBoundary("end") | wildcardPattern(1,Except=":"));
        uncAtStart = textBoundary("start") + "//" + uncSuffix;
        uncAfterAuth = AT + "//" + uncSuffix;
    end

    pth = strrep(pth,"://",":"+AT);

    isUNC = contains(pth,uncAtStart);
    if any(isUNC)
        pth(isUNC) = UT + extractAfter(pth(isUNC),2);
    end

    isAuthUNC = contains(pth,uncAfterAuth);
    if any(isAuthUNC)
        pth(isAuthUNC) = strrep(pth(isAuthUNC),AT+"//",AT+UT);
    end

    pth = regexprep(pth,'/{2,}','/');

    pth = strrep(pth,AT,"//");
    pth = strrep(pth,UT,"//");
end