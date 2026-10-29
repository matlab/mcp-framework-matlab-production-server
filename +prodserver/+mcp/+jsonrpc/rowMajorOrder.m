function idx = rowMajorOrder(sz)
%rowMajorOrder Linear indices that visit an array in row-major order.
%   idx = rowMajorOrder(sz) lists, as a row, the linear indices of an array
%   of size SZ with the last subscript varying fastest -- the order both
%   wire encodings write data in. MATLAB's own order is column-major: the
%   first subscript varies fastest. fromRowMajor is the inverse.

% Copyright 2026 The MathWorks, Inc.

    if isscalar(sz)
        sz = [sz 1];
    end
    idx = reshape(permute(reshape(1:prod(sz), sz), numel(sz):-1:1), 1, []);
end
