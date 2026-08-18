function result = schemaFlexNoBlock(a, b, c, d, e)
% Accumulate and format up to five numeric inputs.

% Copyright 2026 The MathWorks, Inc.

    switch nargin
        case 0
            result = "empty";
        case 1
            result = sprintf("sum=%.2f", a);
        case 2
            result = sprintf("sum=%.2f diff=%.2f", a+b, a-b);
        case 3
            result = sprintf("sum=%.2f diff=%.2f prod=%.2f", a+b+c, a-b, b*c);
        case 4
            result = sprintf("sum=%.2f diff=%.2f prod=%.2f max=%.2f", ...
                a+b+c+d, a-b, b*c, max([a,b,c,d]));
        case 5
            result = sprintf("sum=%.2f diff=%.2f prod=%.2f max=%.2f min=%.2f", ...
                a+b+c+d+e, a-b, b*c, max([a,b,c,d,e]), min([a,b,c,d,e]));
    end
end
