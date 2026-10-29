function [tf, isActive] = isMCPserver(x)
% isMCPserver Is the input the address of a Model Context Protocol Server?

% Copyright 2025-2026 The MathWorks, Inc.

    % Must be a string of some type
    tf = prodserver.mcp.validation.istext(x);
    if tf
        % Must be a valid URI (kind of an expensive check, but
        % authoritative).
        tf = prodserver.mcp.validation.isuri(x);
        if tf
            % Must be an HTTP endpoint that ends with /mcp. HTTP requires
            % a host (RFC 9110), so the authority may not be empty, though
            % isuri allows that.
            address = ("http" | "https") + "://" + ...
                wildcardPattern(1,Inf,Except="/") + ...
                optionalPattern("/" + wildcardPattern()) + "/mcp" + ...
                textBoundary("end");
            tf = matches(x,address);
        end
    end

    % This part only works for MATLAB Production Server MCP servers, all of
    % which have a /ping endpoint. (Replace /mcp with /ping.)
    if nargout == 2 
        if tf
            % ping, not webread here: webread returns char, so testing
            % for a string made every server inactive.
            % One quick try: a question, not a wait for the server.
            isActive = prodserver.mcp.ping(x, timeout=10, retry=1, delay=1);
        else
            isActive = false;
        end
    end
end