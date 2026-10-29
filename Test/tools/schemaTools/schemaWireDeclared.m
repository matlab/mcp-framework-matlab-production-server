function r = schemaWireDeclared(t, d1, dn, du, c, tt, d3)
% Accept every class only the invertible encoding carries.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        t table              % A table
        d1 (1,1) datetime    % One datetime
        dn (1,:) datetime    % Some datetimes
        du (1,1) duration    % One duration
        c categorical        % Categories
        tt timetable         % A timetable
        d3 (1,3) duration    % Three durations
    end
    arguments(Output)
        r (1,1) double       % Combined count
    end

    r = height(t) + numel(dn) + numel(c) + height(tt) + seconds(du) + ...
        sum(seconds(d3)) + 0*year(d1);
end
