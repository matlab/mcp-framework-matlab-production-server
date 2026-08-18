function [dur, totalSec] = schemaDurationNoBlock(h, m, s)
% Create a duration from hours, minutes, and seconds.

% Copyright 2026 The MathWorks, Inc.

    dur = hours(h) + minutes(m) + seconds(s);
    totalSec = seconds(dur);
end
