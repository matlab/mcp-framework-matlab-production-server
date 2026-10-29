function text = andList(words)
%andList Words joined for a message: "a", "a and b", "a, b and c".
%   text = andList(words) joins string array WORDS with commas and a final
%   "and". An empty array gives "".

% Copyright 2026 The MathWorks, Inc.

    arguments
        words string
    end
    if isempty(words)
        text = "";
    elseif isscalar(words)
        text = words;
    else
        text = strjoin(words(1:end-1), ", ") + " and " + words(end);
    end
end
