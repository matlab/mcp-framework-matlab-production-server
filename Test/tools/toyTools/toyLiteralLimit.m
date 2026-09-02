function z = toyLiteralLimit(str,suffix)
% Generate strings with a numeric suffix. 

% Copyright 2026 The MathWorks, Inc.
    arguments(Input)
        str (1,1) string   % String that receives suffixes.
        %#schema {"maxItems": 17, "items": { "minimum": 2, "maximum": 32 } }
        suffix double      % Numeric suffixes for string.  
    end
    arguments(Output)
        %#schema { "maxItems": 17 }
        z string
    end

    z = arrayfun(@(n)str + string(n), suffix);
end
