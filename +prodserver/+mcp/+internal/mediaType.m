function mt = mediaType(value)
%mediaType The bare, case-folded media type of a Content-Type or media range.
%   "Application/JSON ; charset=utf-8" -> "application/json"
%
%   RFC 9110 §8.3.1: parameters follow the first ';' and are not part of the
%   type, and type and subtype are case-insensitive. Whitespace is trimmed
%   AFTER the parameters are removed: optional whitespace may sit before the
%   ';' as well as after it, and trimming first leaves "text/plain " behind,
%   which matches nothing. isMIMETypeText used to do exactly that.
%
%   VALUE may be a char vector, a string array (each element is normalized,
%   which is how acceptsJson passes a split media-range list), or empty.
%   Empty input -- [], '', string.empty -- gives string.empty, so callers can
%   keep using isempty to mean "no Content-Type". Every caller that compares
%   media types normalizes through here, so none can disagree with another
%   about what the same header says.

% Copyright 2026 The MathWorks, Inc.

    if isempty(value)
        mt = string.empty;
        return
    end
    mt = string(value);
    mt = lower(strip(extractBefore(mt + ";", ";")));
end
