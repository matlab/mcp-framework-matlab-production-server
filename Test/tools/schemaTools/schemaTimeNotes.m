function r = schemaTimeNotes(t, d)
% Take a datetime and a duration, each with a %#schema that only annotates.

% Copyright 2026 The MathWorks, Inc.
    arguments(Input)
        %#schema {"title": "Start"}
        t (1,1) datetime    % The start.
        %#schema {"title": "Length"}
        d duration          % How long.
    end
    arguments(Output)
        r (1,1) double      % One.
    end
    r = 1;
end
