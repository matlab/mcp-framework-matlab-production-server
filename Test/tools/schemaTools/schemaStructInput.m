function n = schemaStructInput(s)
% Count the fields of a struct, which an example call describes.

% Copyright 2026 The MathWorks, Inc.
    n = numel(fieldnames(s));
end
