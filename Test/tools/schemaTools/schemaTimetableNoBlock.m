function [TT, nrows, span] = schemaTimetableNoBlock(values, startHour, intervalMin)
% Build a timetable with regular time steps.

% Copyright 2026 The MathWorks, Inc.

    n = numel(values);
    t0 = hours(startHour);
    dt = minutes(intervalMin);
    times = t0 + (0:n-1)' * dt;
    TT = timetable(times, values(:), VariableNames="Value");
    nrows = height(TT);
    span = times(end) - times(1);
end
