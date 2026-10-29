function [d, ok, zone, mixed] = parseISODateTime(text)
%parseISODateTime Parse ISO 8601 date-time text into a datetime.
%   [d, ok] = parseISODateTime(text) accepts exactly these forms:
%
%     2026-01-02
%     2026-01-02T03:04, 2026-01-02T03:04:05, 2026-01-02T03:04:05.250
%
%   optionally followed, after a time, by Z (UTC) or an offset such as
%   -05:00. With no suffix the datetime is unzoned; Z makes it UTC; an
%   offset makes it a datetime in that fixed offset. T and Z may be lower
%   case, as RFC 3339 allows. The fraction may have any number of digits,
%   and the year more than four, with a sign (-0005, 10000). These include
%   every form isoDateTimeText writes. ok is false, and d NaT, for anything
%   else, including dates that don't exist (2026-02-30) and forms that
%   depend on the locale (01/02/2026). MATLAB's own conversion from text
%   guesses at such forms, and rolls 2026-13-01 over into 2027.
%
%   TEXT may be a character row vector, a string array, or a cell array of
%   them, as jsondecode delivers a JSON array; d and ok then have its
%   size, and an element that isn't text (such as [] for null) isn't ok.
%   The whole array is parsed at once.
%
%   [d, ok, zone] = parseISODateTime(text) also returns each element's own
%   time zone: "" (unzoned), "UTC" or an offset such as "-05:00", and a
%   missing string where ok is false. d is in that zone when every element
%   has the same one. If the elements are all zoned but in different
%   zones, d is in UTC: the same instants. If some are zoned and some
%   aren't, there is no one zone to put them in, and d is all NaT: the
%   caller decides, from zone.
%
%   [d, ok, zone, mixed] = parseISODateTime(text) also says whether that
%   happened: whether the elements that parsed mix zoned and unzoned
%   date-times.

% Copyright 2026 The MathWorks, Inc.

    mixed = false;
    if ischar(text) && (isrow(text) || isempty(text))
        text = string(text);
    elseif iscell(text)
        isText = cellfun(@(c) (ischar(c) && (isrow(c) || isempty(c))) || ...
            (isstring(c) && isscalar(c)), text);
        t = strings(size(text));
        t(:) = missing;
        t(isText) = string(text(isText));
        text = t;
    elseif ~isstring(text)
        d = NaT;
        ok = false;
        zone = string(missing);
        return
    end

    sz = size(text);
    t = upper(text(:));                 % Only T and Z have a case
    n = numel(t);
    d = NaT(n, 1);
    zone = strings(n, 1);
    zone(:) = missing;

    % Check the whole form first; then take each part with a pattern that
    % has no optional groups, whose tokens regexp reports reliably.
    ok = ~ismissing(t);
    ok(ok) = ~cellfun(@isempty, cellOf(regexp(t(ok), ...
        "^[+-]?\d{4,}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})?)?$", ...
        "once")));
    k = find(ok);
    if isempty(k)
        d = reshape(d, sz);
        ok = reshape(ok, sz);
        zone = reshape(zone, sz);
        return
    end
    t = t(k);

    date = tokens(t, "^([+-]?\d{4,})-(\d{2})-(\d{2})", 3, "");
    y = str2double(date(:,1));
    mo = str2double(date(:,2));
    dd = str2double(date(:,3));
    clock = tokens(t, "T(\d{2}):(\d{2})", 2, "0");
    h = str2double(clock(:,1));
    mi = str2double(clock(:,2));
    s = str2double(tokens(t, "T\d{2}:\d{2}:(\d{2}(?:\.\d+)?)", 1, "0"));
    z = tokens(t, "T.*(Z|[+-]\d{2}:\d{2})$", 1, "");

    valid = mo >= 1 & mo <= 12 & dd >= 1 & dd <= eomday(y, min(max(mo, 1), 12)) & ...
        h <= 23 & mi <= 59 & s < 60;
    offset = startsWith(z, ["+" "-"]);
    oh = str2double(extractBetween(z(offset), 2, 3));
    om = str2double(extractAfter(z(offset), 4));
    valid(offset) = valid(offset) & oh <= 23 & om <= 59;

    tz = z;
    tz(z == "Z") = "UTC";
    ok(k) = valid;
    zone(k(valid)) = tz(valid);

    % One datetime per zone, since a datetime array has one zone.
    keep = find(valid);
    names = unique(tz(keep));
    mixed = any(names == "") && numel(names) > 1;
    if mixed
        d.TimeZone = "";                % Zoned and unzoned: no one zone
    else
        if isscalar(names)
            d.TimeZone = names;
        else
            d.TimeZone = "UTC";
        end
        for name = names'
            m = keep(tz(keep) == name);
            d(k(m)) = datetime(y(m), mo(m), dd(m), h(m), mi(m), s(m), ...
                TimeZone=name);
        end
    end

    d = reshape(d, sz);
    ok = reshape(ok, sz);
    zone = reshape(zone, sz);
end

function c = cellOf(r)
% regexp returns a cell for a string array, but not for a scalar string.
    if ~iscell(r)
        c = {r};
    else
        c = r;
    end
end

function parts = tokens(t, pattern, count, default)
% The COUNT tokens of PATTERN in each element of T, one row per element,
% or DEFAULT where it doesn't match.
    r = cellOf(regexp(t, pattern, "tokens", "once"));
    parts = repmat(string(default), numel(t), count);
    for k = 1:numel(r)
        if ~isempty(r{k})
            parts(k, :) = r{k};
        end
    end
end
