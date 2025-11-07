function mustBeText(x,var,constraint)
%mustBeText Throw an error if x is not string, char or cell array of char.
%Optional constraint (a function) must also be satisfied.

% Copyright 2023-2025 The MathWorks, Inc.

% Written because validateattributes can't check for cellstr and MATLAB's
% mustBeText doesn't allow customization of the error message.

    validateattributes(x,["string","cell","char"],"nonempty",x,var);
    if iscell(x) && ~iscellstr(x) %#ok<ISCLSTR> -- Already done.
        error(message(msgid("pipeline:VarMustBeCellstr", x, var)));
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
