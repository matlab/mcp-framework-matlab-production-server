function y = toyLogProbe(x)
% Write one log line, which carries the request's context, and return x.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        x (1,1) double    % Value
    end
    arguments(Output)
        y (1,1) double    % The same value
    end
    prodserver.mcp.logging.Log.instance().log("Information", ...
        "prodserver:mcp:TracingEnabled", "probe");
    y = x;
end
