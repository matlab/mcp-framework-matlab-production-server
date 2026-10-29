function later = schemaWireTimes(d1, dn, d3)
% Shift a date by the total of some durations.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        d1 (1,1) datetime    % Start
        dn (1,:) datetime    % Other dates
        d3 (1,3) duration    % Three shifts
    end
    arguments(Output)
        later (1,1) datetime % d1 shifted
    end

    later = d1 + sum(d3) + 0*numel(dn);
end
