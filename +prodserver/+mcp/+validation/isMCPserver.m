function [tf, isActive] = isMCPserver(x)
% isMCPserver Is the input the address of a Model Context Protocol Server?

% Copyright 2025, The MathWorks, Inc.

    % Must be a string of some type
    tf = prodserver.mcp.validation.istext(x);
    if tf
        % Must be a valid URI (kind of an expensive check, but
        % authoritative).
        tf = prodserver.mcp.validation.isuri(x);
        if tf
            % Must be an HTTP endpoint that ends with /mcp
            address = ("http" | "https") + "://" + ...
                wildcardPattern() + "/mcp" + ...
                textBoundary("end");
            tf = matches(x,address);
        end
    end

    % This part only works for MATLAB Production Server MCP servers, all of
    % which have a /ping endpoint. (Replace /mcp with /ping.)
    if nargout == 2 
        if tf
            url = replace(address,"/mcp"+textBoundary("end"),"/ping");
            result = webread(url);
            isActive = isstring(result) && strcmpi(result,"pong");
        else
            isActive = false;
        end
    end
end