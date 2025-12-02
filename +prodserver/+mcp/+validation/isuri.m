function tf = isuri(x,opts)
% isuri Is the input a valid URI?

% Copyright 2025, The MathWorks, Inc.

    arguments
        x 
        opts.pathChars string = "~.-_";
        opts.pathSep string = "/";
    end

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.internal.Constants

    % URI object is trivially a URI.
    if isa(x,"matlab.net.URI")
        tf = true;
        return
    end

    % structure with the right fields (output of parseURI) is also a
    % legitimate URI. A bit of a self-reflective trick here: if the URI
    % in the structure parses to the same structure, the original structure
    % was a valid URI.
    fields = ["scheme","host","port","userInfo","path","query","uri"];
    if isstruct(x) && isempty(setxor(fields,fieldnames(x)))
        xx = prodserver.mcp.io.parseURI(x.uri);
        if isequal(xx,x)
            tf = true;
            return;
        end
    end
    
    % Generally shouldn't error on this "is*" function. A bit of tension
    % here, since tf should, in general, be the same size as the input x.
    % But we don't want to return multiple megabytes of false if we're
    % passed an image, for example.
    if isempty(x) || prodserver.mcp.validation.istext(x) == false
        tf = false;
        return;
    end

    pathSep = characterListPattern(opts.pathSep);

    % Structure:
    %   scheme authority path query fragment

    % Optimization? Attempting to sacrifice space to gain time. These parts
    % of the URI pattern never change.
    persistent suffix authority ipv6 scheme pathRoot
    if isempty(authority)
        % file:, for example.
        scheme = Constants.SchemeNamePattern + ":";
        
        % Labels are allowed to start with a number. But they can't be only
        % numbers. Those are IPV6 and IPV6 addresses, covered by a
        % different pattern. Since regular expressions can't really count,
        % this is hard to express via a pattern. So this label is too
        % permissive. But we put the hostname under a microscope later.
        % Allow both underscore and dash.
        label = asManyOfPattern(alphanumericsPattern(1) | "_" | "-");
        
        %
        % Pattern of authority
        %

        % Infrequently used, but allowed: http://user@localhost:9910
        userInfo = label + optionalPattern(":" + label) + "@";
        hostname = label + asManyOfPattern(optionalPattern("."+label));

        % 127.0.0.1, for example -- four digits, three dots
        ipv4 = digitsPattern + "." + digitsPattern + "." + ...
            digitsPattern + "." + digitsPattern ;

        % Probably allows some invalid ipv6 addresses
        hexList = asManyOfPattern(characterListPattern("0123456789abcdefABCDEF:"));
        ipv6 = "[" + hexList + "]";

        host = hostname | ipv4 | ipv6;
        port = ":"+digitsPattern;  % Allows numbers past uint16
        authority = "//" + optionalPattern(userInfo) + host + ...
            optionalPattern(port) ;

        %
        % Paths may be absolute (rooted) or relative.
        % 

        % Permit /, C: and /C:, or none of them.
        drive = optionalPattern(lettersPattern(1)+":");
        pathRoot = optionalPattern(pathSep) + drive;
       
        % URLs may end with a query section and a fragment.
        query = "?" + asManyOfPattern(wildcardPattern(Except="#"));
        fragment = "#" + label;

        suffix = optionalPattern(query) + optionalPattern(fragment);
    end

    % A path segment -- unreserved characters or percent-encoding of
    % reserved characters.
    segment = asManyOfPattern(alphanumericsPattern(1) | ...
        characterListPattern(opts.pathChars) | Constants.percentPattern);
    pth = segment + optionalPattern(asManyOfPattern(pathSep+segment));

    % http://localhost:9910
    % http://localhost:9910/path/to/resource
    % file:C:/file/system/path/to/data.mat
    uri = (scheme + authority | ...
           scheme + authority + pathSep + pth | ...
           scheme + pathRoot + pth ) + suffix;
    tf = matches(x,uri);

    % Still must check for valid host name. This is a lot of work. How
    % necessary is this accuracy?
    if tf && contains(x, authority)
        endAuthority = textBoundary("end") | "/";
        if contains(x,"@")
            address = extractBetween(x,"@",endAuthority);
        elseif contains(x,ipv6)
            address = extract(x,ipv6);
            cN = count(address,":");
            tf = cN > 0 && cN < 7;
            return;
        else
            address = extractBetween(x,"//",endAuthority);
        end
        if contains(address,":")
            host = extractBefore(address,":");
        else
            host = address;
        end
        % Every segment of the host name must contain at least one letter
        % unless there are exactly three dots and there are no letters at
        % all.
        segments = split(host,".");
        if count(host,".") == 3 && count(host,lettersPattern(1)) == 0
            % IPV4 detected!
            return;
        end

        % Require a letter in every segment.
        for n = 1:numel(segments)
            tf = tf && count(segments{n},lettersPattern(1)) > 0;
            if tf == false
                break;
            end
        end
    end
end
