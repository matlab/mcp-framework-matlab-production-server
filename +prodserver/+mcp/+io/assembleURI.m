function str = assembleURI(uri)
%assembleURI Create a URI string from the parts of a parsed URI:
%    scheme, userinfo, host, port, path, query

% Copyright (c) 2024-2025, The MathWorks, Inc.

    import prodserver.mcp.internal.Constants

    str = strings(1,numel(uri));
    for n = 1:numel(uri)

        % Schemes are case-insensitive by standard.
        str(n) = lower(uri(n).scheme) + ":";
    
        % Accumulate authority
        authority = "";
        if ~isempty(uri(n).userInfo)
            authority = uri(n).userInfo + "@";
        end
        if ~isempty(uri(n).host)
            authority = authority + uri(n).host;
        end
        if ~isempty(uri(n).port)
            prt = -1;
            if isstring(uri(n).port)
                prt = str2double(uri(n).port);
            end
            if prt >= 0
                authority = authority + ":" + string(uri(n).port);
            end
        end
        if strlength(authority) > 0
            authority = Constants.AuthorityPrefix + authority;

            % Separate path from scheme and authority by / -- but never
            % allow two // there when the URI has an authority.
            if startsWith(uri(n).path,Constants.URISep) == false
                authority = authority + Constants.URISep;
            end
            
            str(n) = str(n) + authority;
        end

        if ~isempty(uri(n).path)
            str(n) = str(n) + uri(n).path;
        end
        if ~isempty(uri(n).query)
            str(n) = str(n) + "?" + strjoin(uri(n).query,"&");
        end
    end
end