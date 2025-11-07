function value = getHeaderValue(name, nvp)
%getHeaderValue Return the value associated with the given name in a list
%of HTTP headers -- an Nx2 cell array.

% Copyright 2025, The MathWorks, Inc.

    % Initialize the output value as empty
    value = [];

    if isa(nvp,"matlab.net.http.HeaderField")
        n = { nvp.Name };
        v = { nvp.Value };
        nvp = [n;v]';
    end
    % Check if the number of input arguments is even
    sz = size(nvp);
    if sz(2) ~= 2
        error('Name-value pairs must be provided in pairs.');
    end
    
    % Loop through the name-value pairs
    for i = 1:sz(1)
        currentName = nvp{i,1};
        currentValue = nvp{i,2};
        
        % Check if the current name matches the input name. Header names
        % are by definition case-insensitive.
        if strcmpi(currentName, name)
            value = currentValue;
            return; % Exit the function once the value is found
        end
    end
    
    % If the name is not found, return an empty value
end

% Mostly written by MATLAB Copilot. 