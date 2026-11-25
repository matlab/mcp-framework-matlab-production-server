function s = isoDateTimeText(d, natText)
%isoDateTimeText ISO 8601 text of a datetime, for both wire encodings.
%   s = isoDateTimeText(d) returns a string array the size of D:
%   2026-01-02T03:04:05.000 when D is unzoned, with a Z suffix when it is
%   in UTC, and with its offset (such as -05:00) in any other zone. NaT
%   elements are missing strings, which jsonencode writes as null.
%
%   The seconds have at least three decimal places, and as many more, up
%   to nine, as the value needs: 05.000123456, not 05.000. A datetime
%   holds nanoseconds, and the invertible encoding must keep them.
%
%   s = isoDateTimeText(d, natText) writes NaT elements as NATTEXT instead,
%   as the invertible encoding does with "NaT".
%
%   A datetime of Inf or -Inf, which ISO 8601 has no form for, is an
%   error, prodserver:mcp:IncompatibleArgumentType.
%
%   parseISODateTime reads every form this writes.

% Copyright 2026 The MathWorks, Inc.

    arguments
        d datetime
        natText string = missing
    end

    % ISO 8601 has no form for an infinite datetime: string() writes it as
    % 0InfInf, which no client reads as a date-time, and which the
    % invertible encoding would read back as text.
    if any(isinf(d), "all")
        error("prodserver:mcp:IncompatibleArgumentType", ...
            "A datetime of Inf or -Inf can't be sent: ISO 8601 text has " + ...
            "no form for it, in either wire encoding. Use NaT, or a " + ...
            "finite date.");
    end

    tz = d.TimeZone;
    clock = "-MM-dd'T'HH:mm:ss.SSSSSSSSS";
    if isempty(tz)
        s = string(d, clock);
    elseif strcmpi(tz, "UTC")
        s = string(d, clock + "'Z'");
    else
        s = string(d, clock + "XXX");
    end
    % The year, written here: at least four digits, with a sign before
    % year 0 (-0005). Not the format's yyyy, the year of the era, which
    % writes year -5 as 0006; nor uuuu, which in a time zone writes -005.
    y = year(d);
    years = pad(string(abs(y)), 4, "left", "0");
    years(y < 0) = "-" + years(y < 0);
    s = years + s;
    % Trailing zeros beyond the milliseconds say nothing.
    s = regexprep(s, "(\.\d{3}\d*?)0+(?=$|Z|[+-])", "$1");
    s(isnat(d)) = natText;
end
