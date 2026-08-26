function maxItems = sizeFromValidation(validationSize)
%sizeFromValidation Compute maxItems from argument block size validation.
%   maxItems = sizeFromValidation(validationSize) returns the total number
%   of elements implied by the size validation from an argument block. If
%   any dimension is unrestricted, returns Inf. Returns 0 if validationSize
%   is empty.
%
%   validationSize is the Validation.Size field from a metafunction
%   signature entry — an array of matlab.metadata.FixedDimension and/or
%   matlab.metadata.UnrestrictedDimension objects.

% Copyright 2026 The MathWorks, Inc.

    if isempty(validationSize)
        maxItems = 0;
        return;
    end

    maxItems = 1;
    for i = 1:numel(validationSize)
        if isa(validationSize(i), 'matlab.metadata.UnrestrictedDimension')
            maxItems = Inf;
            return;
        elseif isa(validationSize(i), 'matlab.metadata.FixedDimension')
            maxItems = maxItems * double(validationSize(i).Length);
        end
    end
end
