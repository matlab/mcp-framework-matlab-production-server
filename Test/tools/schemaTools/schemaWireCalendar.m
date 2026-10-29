function y = schemaWireCalendar(c)
% Count calendar months.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        c calendarDuration   % A calendar duration
    end
    arguments(Output)
        y (1,1) double       % Months
    end

    y = calmonths(c);
end
