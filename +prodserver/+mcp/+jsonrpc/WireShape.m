classdef WireShape
% WireShape Whether a parameter holds one element, several, or either.
%   A scalar datetime or duration has a different encoding from an array of
%   them, so their schemas depend on shape.
%
%   WireShape.fromSize(validationSize) is the shape a declared size
%   allows: Scalar for (1,1), Array for a fixed size of more than one
%   element, and Either when the size is unrestricted or not declared, since
%   such a parameter may hold one element.

% Copyright 2026 The MathWorks, Inc.

    enumeration
        Scalar
        Array
        Either
    end

    methods (Static)
        function shape = fromSize(validationSize)
            import prodserver.mcp.jsonrpc.WireShape
            if isempty(validationSize)
                shape = WireShape.Either;
                return
            end
            n = prodserver.mcp.jsonrpc.sizeFromValidation(validationSize);
            if n == 1
                shape = WireShape.Scalar;
            elseif isinf(n)
                shape = WireShape.Either;
            else
                shape = WireShape.Array;
            end
        end
    end
end
