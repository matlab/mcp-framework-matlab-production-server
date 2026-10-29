function value = fromRowMajor(flat, sz)
%fromRowMajor An array of size SZ from its elements in row-major order.
%   value = fromRowMajor(flat, sz) is the array whose elements, last
%   subscript varying fastest, are FLAT. It is the inverse of indexing with
%   rowMajorOrder, for any number of dimensions, empty arrays, cells and
%   char. permute never conjugates, so complex values come back as they
%   were.

% Copyright 2026 The MathWorks, Inc.

    if isscalar(sz)
        sz = [sz 1];
    end
    value = permute(reshape(flat, fliplr(sz)), numel(sz):-1:1);
end
