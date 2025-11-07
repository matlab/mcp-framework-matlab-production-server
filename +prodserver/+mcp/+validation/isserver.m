function [tf, isActive] = isserver(x,opts)
% isserver Is the input the address of a MATLAB Production Server?

% Copyright 2025, The MathWorks, Inc.

    arguments
        x
        opts.retry double = 2
        opts.timeout double = 10
    end

    % Must be a string of some type
    tf = prodserver.mcp.validation.istext(x);
    if tf
        % Must be a valid URI (kind of an expensive check, but
        % authoritative).
        tf = prodserver.mcp.validation.isuri(x);
        if tf
            % Must be only the <scheme>://<authority>/ portion of a URI.
            % Trailing / is optional.
            address = ("http" | "https") + "://" + ...
                wildcardPattern(Except="/") + optionalPattern("/") + ...
                textBoundary("end");
            tf = matches(x,address);
        end
    end

    if nargout == 2 
        if tf
            ping = "api/health";
            if endsWith(x,"/")
                url = x + ping;
            else
                url = x + "/" + ping;
            end
            webOpts = weboptions(Timeout=opts.timeout);
            n = 1;
            while n <= opts.retry
                try
                    result = webread(url,webOpts);
                catch ex
                    % Wait a second and try again on 404
                    if contains(ex.identifier,"HTTP404")
                        pause(1);
                    else
                        rethrow(ex);
                    end
                end
                n = n + 1;
            end
            isActive = isstruct(result) && isfield(result,"status") && ...
                strcmpi(result.status,"ok");
        else
            isActive = false;
        end
    end
end