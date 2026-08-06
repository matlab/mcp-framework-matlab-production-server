function C = matrixMultiply(A, B)
% Multiply two matrices or vectors.
%
% The orientation of A and B determines the result:
%   Row * Column (1x3 * 3x1) -> scalar (dot product)
%   Column * Row (3x1 * 1x3) -> matrix (outer product)
%   Matrix * Vector (3x3 * 3x1) -> vector
%
% Without wire encoding, JSON arrays have no orientation. Both row and
% column vectors arrive as column vectors via jsondecode, producing
% dimension errors or wrong results.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        % Left matrix or vector operand
        A (:,:) double
        % Right matrix or vector operand (inner dimensions must match A)
        B (:,:) double
    end
    arguments(Output)
        % Product A*B (shape determined by input dimensions)
        C (:,:) double
    end

    C = A * B;

end
