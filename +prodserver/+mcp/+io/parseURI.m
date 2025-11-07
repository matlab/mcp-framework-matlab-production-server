function u = parseURI(uri)
%parseURI Parse a URI into a structure with fields for each component.
%
%   scheme, userinfo, host, port, path, query
%
%And a copy of the original URI in the 'uri' field. 
%
%Assumes that URI is well-formatted. Does minimal checking for
%syntax errors. 

% Copyright (C) 2022-2024, The MathWorks, Inc.

    import prodserver.mcp.internal.Constants
    
    import prodserver.mcp.validation.istext
    import prodserver.mcp.io.normalizeURI


    if istext(uri) && ~isstring(uri)
        uri = string(uri);
    end
    
    void = cell(numel(uri),1);
    u = struct("scheme",void,"host",void,"port",void,"userInfo",void, ...
        "path",void,"query",void);

    for n=1:numel(uri)

        % Keep a copy of the original URI
        u(n).uri = uri(n);
    
        %
        % Extract scheme: scheme ":"
        %
        % schemePattern = lineBoundary("start") + ...
        %     asManyOfPattern(wildcardPattern(1,"Except",":"));
        % 

        % Always lower case: schemes are case-insensitive by standard.
        u(n).scheme = lower(extract(uri(n), Constants.SchemeNamePattern));
        if isempty(u(n).scheme)
            error("Scheme missing from URI %s.", uri(n));
        end

        % RFC 3986 says: (And here ALPHA is strictly letters.)
        %
        % scheme = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
        if matches(u(n).scheme,Constants.SchemeName) == false
            error("prodserver:mcp:InvalidSchemeName", ...
                "Invalid scheme name '%s'.", u(n).scheme);
        end
    
        %
        % Extract authority: [userinfo "@"] host [":" port]
        %
    
        % Strip off scheme, leaves string starting with :
        uri(n) = strrep(uri(n),u(n).scheme,"");

        % Extract authority, which extends to the next /, ? # or the end of
        % the URI. Authority only present if // follows the :
        authority = extract(uri(n),lookBehindBoundary("://") + ...
            asManyOfPattern(wildcardPattern(1,Except=characterListPattern("/?#"))));
    
        % User info is everything up to the @
        userPattern = asManyOfPattern(wildcardPattern(1,"Except","@"))+ ...
            lookAheadBoundary("@");
        u(n).userInfo = extract(authority, userPattern);
    
        % Punch out user info (may be empty), leaves // at the start of the
        % string. Don't forget to remove @, if found.
        usr = u(n).userInfo; if ~isempty(usr), usr = usr + "@"; end
        if ~isempty(usr)
            uri(n) = strrep(uri(n),usr,""); 
        end
    
        % Address is everything left between // and /. No ambiguity with
        % path components, because authority starts with // and path may
        % not.
        addressPattern = lookBehindBoundary("://") + ...
            asManyOfPattern(alphanumericsPattern | "." | "+" | "-" ) + ...
            optionalPattern(":" + digitsPattern(1,inf)) + lookAheadBoundary("/");
            
        % Network address (host:port)
        address = extract(uri(n),addressPattern);
        addr = split(address,":");
        u(n).host = string.empty;
        u(n).port = -1;
        if strlength(address) > 0
            u(n).host = addr(1);
            if numel(addr) == 2
                u(n).port = addr(2);
            end
        end
    
        % 
        % Extract path
        %
    
        % Strip off address, which may be empty. Remove leading : anyway.
        if ~isempty(address)
            uri(n) = extractAfter(uri(n),address); 
        else
            uri(n) = extractAfter(uri(n),":"); 
        end    

        % The actual path is everything up to the first ? 
        u(n).path = extractBefore(uri(n),textBoundary("end") | "?");
    
        %
        % Extract query - everything from the ? to the end of the string
        %
    
        queryPattern = lookBehindBoundary("?") + wildcardPattern + ...
            lineBoundary("end");
        u(n).query = split(extract(uri(n),queryPattern),"&");

        % Decode path, authority and query -- encoding preserved in
        % u(n).uri.
        u(n) = prodserver.mcp.io.percentDecode(u(n));
    end
    
    % Foward slashes only, and no empty segments. And other rules as
    % warranted...
    u = normalizeURI(u);

end