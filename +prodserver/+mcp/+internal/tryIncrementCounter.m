function tryIncrementCounter(name, value)
%tryIncrementCounter Add to a metric, without failing if the write fails.
%   tryIncrementCounter(name, value) adds VALUE to the counter NAME with
%   prodserver.metrics.incrementCounter. If the write fails -- as on a
%   server where it raised "Error writing to output stream. iostream stream
%   error" now and then -- the count is lost and a warning,
%   MetricWriteFailed, is logged, at most once a minute for each metric,
%   so that a steady failure doesn't log every request. It never raises: a
%   lost count must not fail the request it counts.

% Copyright 2026 The MathWorks, Inc.

% Contract:
%   Kind:      command
%   Requires:  none (any input)
%   Ensures:   the counter is incremented, or the loss is logged (throttled)
%   Raises:    none

    try
        prodserver.metrics.incrementCounter(name, value);
    catch err
        try
            prodserver.mcp.logging.Log.instance().logOncePer( ...
                "MetricWriteFailed|" + string(name), 60, ...
                prodserver.mcp.logging.Level.Warning, ...
                "prodserver:mcp:MetricWriteFailed", ...
                "Lost %s from the metric %s: %s", ...
                string(value), string(name), string(err.message));
        catch
            % Logging never raises, but nothing here may.
        end
    end
end
