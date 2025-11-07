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

    persistent authorityPattern
    if isempty(authorityPattern)
        authorityPattern = "://"+asManyOfPattern( ...
            wildcardPattern(1,Except=characterListPattern("?#/")))+"/";
    end

    if istext(uri)
        hasAuthority = contains(uri,authorityPattern);
        uri = normalizePath(uri,hasAuthority);
    elseif isa(uri,"dictionary")
        x = keys(uri)';
        hasAuthority = contains(uri(x),authorityPattern);
        uri(x) = normalizePath(uri(x),hasAuthority);
    elseif isstruct(uri)
        np = num2cell(normalizePath([uri.path]));
        [uri.path] = np{:};
        hasAuthority = contains([uri.uri],authorityPattern);
        np = num2cell(normalizePath([uri.uri],hasAuthority));
        [uri.uri] = np{:};
    end
end

function np = normalizePath(p,hasAuthority)
% Normalize only the path part of the URI. DO NOT modify the parameter
% part. (This took a long time to find.)
% 
% Normalization means:
%
%  * Turn all \ into /
%  * Collapse empty segments // into /.
%  * Never collapse authority-defining //

    import prodserver.mcp.internal.Constants

    if nargin == 1
        hasAuthority = false(size(p));
    end

    if contains(p,Constants.ParamStart)
        pth = extractBefore(p,Constants.ParamStart);
        param = extractAfter(p,pth);
        pth = strrep(pth,"\","/");
        pth = preventCollapseOfAuthority(pth,hasAuthority);
        np = pth + param;
    else
        np = strrep(p,"\","/");
        np = preventCollapseOfAuthority(np,hasAuthority);
    end
end

function pth = preventCollapseOfAuthority(pth,hasAuthority)

    persistent authorityToken
    if isempty(authorityToken)
        authorityToken = lookBehindBoundary(textBoundary("start") + ...
            asManyOfPattern(wildcardPattern(1,Except=":"))) + "://";
    end

    pth(hasAuthority) = replace(pth(hasAuthority),authorityToken,":/:/");
    pth = strrep(pth,"//","/");
    pth = strrep(pth,":/:/","://");
end