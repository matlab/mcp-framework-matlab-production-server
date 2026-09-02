function nvp = setHeaderValue(nvp, name, value)
%setHeaderValue Set the value associated with the given name in a list
%of HTTP headers -- an Nx2 cell array or an array of
%matlab.net.http.HeaderField.

% Copyright 2026 The MathWorks, Inc.

    arguments (Input)
        nvp 
        name string {mustBeVector}
        value cell { mustBeVector, prodserver.mcp.validation.mustBeSameSize(1, name, value) }
    end

    if isa(nvp,"matlab.net.http.HeaderField") || isstruct(nvp)
        % All the names as a cell array;
        if ischar(nvp(1).Name)
            n = { nvp.Name };
        elseif isstring(nvp(1).Name)
            n = [ nvp.Name ];
        end
        sz = [numel(n),2];
    elseif iscell(nvp)
        % First column
        n = nvp(:,1);
        sz = size(nvp);
    else
        error("prodserver:mcp:InvalidHeaderListType", ...
            "Header list must be structure vector, Nx2 cell array or " + ...
            "vector of matlab.net.http.HeaderField. Input list has type %s.", ...
            class(nvp));
    end
    
    % Check if the number of input arguments is even
    if sz(2) ~= 2
        error("prodserver:mcp:UnevenNVP", ...
            "Name-value pairs must be provided in pairs. List has uneven length: %d", ...
            prod(sz));
    end

    % Find the names that match 
    k = strcmpi(n,name);
    if nnz(k) ~= numel(name)
        error("prodserver:mcp:AmbiguousHeaderName", ...
 "Found %d matching headers when expecting %d. Specify unique, existing names.", ...
            nnz(k), numel(name));
    end
    
    % Loop through the name-value pairs
    found = find(k);
    for i = 1:numel(found)
        if isa(nvp,"matlab.net.http.HeaderField") || isstruct(nvp)
            nvp(found(i)).Value = value{i};
        elseif iscell(nvp)
            nvp{found(i),2} = value{i};
        end
    end

end

