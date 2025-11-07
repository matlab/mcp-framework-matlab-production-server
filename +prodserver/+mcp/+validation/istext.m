function tf = istext(x)
% istext Is the input a string array, character vector or a cell array of
% character vectors.

% Copyright 2025, The MathWorks, Inc.

    tf = all(isstring(x)) || iscellstr(x) || (ischar(x)&&(isrow(x)||isempty(x))) ;
end