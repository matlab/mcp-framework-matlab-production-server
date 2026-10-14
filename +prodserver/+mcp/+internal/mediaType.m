function mt = mediaType(value)
%mediaType The bare media type of a Content-Type or Accept value.
%
%   MT = mediaType(VALUE) returns the type/subtype part of VALUE, lower case,
%   with surrounding whitespace and any parameters removed:
%
%     mediaType("Application/JSON; charset=utf-8")   % "application/json"
%     mediaType("text/event-stream;q=0.9")           % "text/event-stream"
%
%   Media types are case-insensitive and may carry parameters (RFC 9110
%   8.3.1), so any comparison against a literal type must go through this
%   first. Comparing the raw header value is how a client sending
%   "application/json; charset=utf-8" came to have its JSON refused as
%   not-JSON.
%
%   VALUE may be a string array, in which case MT is the same size. An absent
%   value -- the [] that getHeaderValue returns for a missing header -- gives
%   "", which matches no media type.

% Copyright 2026 The MathWorks, Inc.

    if isempty(value)
        mt = "";
        return
    end

    % Appending ';' makes extractBefore work for values with no parameters.
    mt = lower(strtrim(extractBefore(string(value) + ";", ";")));
end
