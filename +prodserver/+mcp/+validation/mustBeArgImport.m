function mustBeArgImport(x)
% mustBeArgImport Error if x is not an argument import structure.

% Copyright 2025, The MathWorks, Inc.

    % Allow empty
    if isempty(x)
        return;
    end

    % If it isn't empty, it must be a scalar structure with
    % matlab.io.Import objects as the value of every field.
    validateattributes(x, {'struct'}, {'scalar'});

    fields = fieldnames(x)';

    if isempty(fields)  % Nope, not allowed.
        error("prodserver:mcp:EmptyArgImporter", "Argument import " + ...
            "structure may not be empty. Field names must match input " + ...
            "parameter names.");
    end

    % Require every field be a subclass of matlab.io.ImportOptions. fields
    % is a cell-array, therefore so is f. 
    for f = fields
        if isa(x.(f{1}),"matlab.io.ImportOptions") == false
            error("prodserver:mcp:BadArgImporter", "Invalid type for " + ...
                "'%s' import options: '%s'. Import options must be " + ...
                "a matlab.io.ImportOptions object.",f,class(x.(f{1})));
        end
    end
end
