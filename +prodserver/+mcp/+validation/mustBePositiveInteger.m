function mustBePositiveInteger(x)
%mustBePositiveInteger If x is not a positive, non-empty integer, error.

% Copyright 2025, The MathWorks, Inc.

    validateattributes(x,'numeric',{'integer','positive','nonempty'});
end
