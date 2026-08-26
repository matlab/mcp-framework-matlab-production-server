function [result, count] = schemaAnnotated(config, values, threshold)
% Process values using config parameters and a threshold.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        % Configuration object with name and mode fields.
        %#schema { "type": "object", "properties": { "name": { "type": "string" }, "mode": { "type": "string" } } }
        config struct
        % Numeric values to process.
        %#schema +{ "minItems": 1 }
        values (:,1) double
        threshold (1,1) double   % Cutoff value
    end

    arguments(Output)
        % Filtered values exceeding threshold.
        %#schema +{ "minItems": 0 }
        result (:,1) double
        count (1,1) uint32       % Number of values exceeding threshold
    end

    mask = values > threshold;
    result = values(mask);
    count = uint32(sum(mask));
end
