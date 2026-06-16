function mustBeImportOptions(x)
% mustBeImportOptions Allow import options to be empty or 
% matlab.io.ImportOptions. This function is required because [] is not an
% ImportOptions subclass and matlab.io.ImportOptions.empty generates an
% error.

% Copyright 202, The MathWorks, Inc.

    if isempty(x)
        return;
    end

    validateattributes(x,"matlab.io.ImportOptions",{"scalar"});

end
