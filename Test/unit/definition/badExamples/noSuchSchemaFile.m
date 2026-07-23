function y = noSuchSchemaFile(x)
% Test example for bad literal schema data.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments(Input)
        % This argument specifies invalid literal JSON.
        %#schema /non/Existent/Schema/File.json
        x double
    end
    arguments(Output)
        % No errors here
        y double
    end
    
    y = f(x);
end