function u = redactURI(uri)
%redactURI Remove the query and userinfo of a caller-supplied input URI.
%
%   U = prodserver.mcp.io.redactURI(URI) returns URI's scheme, authority and
%   path, with any userinfo and query removed and a note that a query was
%   removed (G11; FS §8.3). Every caller-supplied plain input URI is reduced
%   this way before it is echoed in a client message or written to the log,
%   then bounded by prodserver.mcp.protocol.echo (NFR-14). A fragment goes
%   with the query; text with no scheme is returned with its query removed
%   the same way. Leading and trailing whitespace is removed.
%
%     redactURI("https://user:pw@host/a/b.csv?sig=x")  % "https://host/a/b.csv (query removed)"
%
%   The URI need not be valid. A password typed without percent-encoding
%   may hold "/", "?" or "#", which end the authority early: where the
%   authority has no "@", but a ":" with no port after it, the userinfo is
%   taken to end at the first "@" after it that a host name follows. A
%   port, as in host:9910, leaves an "@" in the path or query alone.
%
%   See also prodserver.mcp.protocol.echo

% Copyright 2026 The MathWorks, Inc.

    arguments
        uri (1,1) string
    end

    u = strip(uri);
    parts = regexp(u, "^([A-Za-z][A-Za-z0-9+.-]*://)(.*)$", "tokens", "once");
    if isempty(parts)
        [u, removed] = dropQuery(u);
    else
        parts = string(parts);     % regexp's tokens are char: + would add their codes
        rest = parts(2);
        % The authority as RFC 3986 reads it: up to the first "/", "?" or "#".
        authority = extractBefore(rest + "/", regexpPattern("[/?#]"));
        dropped = "";
        if contains(authority, "@")
            % As RFC 3986 reads it: the userinfo ends at the authority's
            % last "@".
            at = strfind(authority, "@");
            dropped = extractBefore(rest, at(end));
            rest = extractAfter(rest, at(end));
        elseif ~isempty(regexp(authority, ":(?![0-9]*$)", "once"))
            % A ":" with no port after it begins a password, which a raw
            % "/", "?" or "#" cut short: the userinfo ends at the first
            % "@" after it that a host name, then the end or a delimiter,
            % follows. Not for host:port, whose path or query may hold an
            % "@" of its own, such as ?mail=a@b.com.
            at = regexp(rest, "@(?=[^/?#@\s]+([/?#]|$))", "once");
            if ~isempty(at)
                dropped = extractBefore(rest, at);
                rest = extractAfter(rest, at);
            end
        end
        [rest, removed] = dropQuery(rest);
        % A "?" or "#" in what was dropped may have begun a query.
        removed = removed || contains(dropped, ["?", "#"]);
        u = parts(1) + rest;
    end
    if removed
        u = u + " (query removed)";
    end
end

function [u, removed] = dropQuery(u)
% U up to its first "?" or "#", and whether there was one.
    query = regexp(u, "[?#]", "once");
    removed = ~isempty(query);
    if removed
        u = extractBefore(u, query);
    end
end
