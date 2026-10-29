function tf = isCharText(matlabClass, validationSize)
%isCharText True if a parameter of a char class is one JSON string.
%   tf = isCharText(matlabClass, validationSize) is true if MATLABCLASS is
%   "char" and VALIDATIONSIZE, the declared size (empty if none), allows a
%   single row: a char row vector is one string, not an array of
%   characters. A declared size that fixes more than one row, such as
%   (2,3), describes several strings. Both schema paths use this rule.

% Copyright 2026 The MathWorks, Inc.

    tf = matlabClass == "char";
    if tf && ~isempty(validationSize) && ...
            isa(validationSize(1), 'matlab.metadata.FixedDimension')
        tf = double(validationSize(1).Length) <= 1;
    end
end
