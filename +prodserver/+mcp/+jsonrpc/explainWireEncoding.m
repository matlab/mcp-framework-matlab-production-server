function parameters = explainWireEncoding(parameters,io,external)
% Add the wire encoding reference to the description of each parameter.

% Copyright 2026 The MathWorks, Inc.

    % For every parameter, except the externalized ones...
    for p = setdiff(keys(parameters)', external, "stable")
        parameters(p).description = prodserver.mcp.jsonrpc.withWireEncodingMsg( ...
            parameters(p).description, io);
    end
end
