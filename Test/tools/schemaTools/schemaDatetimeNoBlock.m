function [dt, dow, serial] = schemaDatetimeNoBlock(year, month, day)
% Construct a datetime and return day-of-week and serial date number.

% Copyright 2026 The MathWorks, Inc.

    dt = datetime(year, month, day);
    dow = string(dt, "eeee");
    serial = datenum(dt);
end
