function value = getHeaderValue(name, nvp)
%getHeaderValue Return the value associated with the given name in a list
%of HTTP headers -- an Nx2 cell array, a matlab.net.http.HeaderField array,
%or a struct array with Name and Value fields.

% Copyright 2025-2026 The MathWorks, Inc.

    % Initialize the output value as empty
    value = [];

    % No headers at all is a legitimate state -- a 202 or 204 response
    % carries none -- and the answer to "what is this header's value" is
    % simply empty. An Nx2 shape check on {} would see 0 columns and read
    % that as a malformed list.
    if isempty(nvp)
        return
    end

    % A HeaderField array, or a struct array with the same Name and Value
    % fields, becomes the Nx2 cell array the loop below expects.
    if isa(nvp,"matlab.net.http.HeaderField") || ...
            (isstruct(nvp) && all(isfield(nvp,["Name" "Value"])))
        n = { nvp.Name };
        v = { nvp.Value };
        nvp = [n;v]';
    end
    % Check if the number of input arguments is even
    sz = size(nvp);
    if sz(2) ~= 2
        error('prodserver:mcp:BadHeaders', ...
            'Name-value pairs must be provided in pairs.');
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