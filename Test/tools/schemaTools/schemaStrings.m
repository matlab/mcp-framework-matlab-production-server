function r = schemaStrings(code, name, tags)
% Accept arguments whose %#schema limits a string's length or form, or
% requires an array's items to be unique.

% Copyright 2026 The MathWorks, Inc.
    arguments(Input)
        %#schema {"pattern": "^[A-Z]{3}-\\d{2}$"}
        code (1,1) string     % Three capitals, a hyphen and two digits.
        %#schema {"minLength": 2, "maxLength": 5}
        name (1,1) string     % Two to five characters.
        %#schema {"uniqueItems": true}
        tags (1,:) string     % Distinct tags.
    end
    arguments(Output)
        r (1,1) double        % The number of tags.
    end
    r = numel(tags);
end
