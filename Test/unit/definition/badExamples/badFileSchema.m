function y = badFileSchema(x)
% Test example for bad literal schema data.
    arguments(Input)
        % This argument specifies invalid literal JSON.
        %#schema badX.json
        x double
    end
    arguments(Output)
        % No errors here
        y double
    end
    
    y = f(x);
end