function mustBeText(x,var,constraint)
%mustBeText Throw an error if x is not string, char or cell array of char.
%Optional constraint (a function) must also be satisfied.

% Copyright 2023-2025 The MathWorks, Inc.

% Written because validateattributes can't check for cellstr and MATLAB's
% mustBeText doesn't allow customization of the error message.

    if nargin == 1
        extra = {};
    elseif nargin == 2
        extra = { var };
    elseif nargin == 3
        extra = { var, constraint };
    end
    validateattributes(x,["string","cell","char"],["nonempty","vector"],extra{:});

    if iscell(x) && ~iscellstr(x) %#ok<ISCLSTR> -- Already done.
        error("prodserver:mcp:VarMustBeCellstr", ...
            "In order to be text, variable %s with type cell must be " + ...
            "cellstr.", var);
    end

    if nargin > 2
        try 
            tf = feval(constraint,x);
        catch 
            tf = false;
        end
        if tf == false
            error("prodserver:mcp:ConstraintViolation", ...
                  "%s does not satisfy constraint %s.", ...
                var, func2str(constraint));
        end
    end
end
