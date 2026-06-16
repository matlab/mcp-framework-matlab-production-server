function mustBePortNumber(x)
%mustBePortNumber Error if X is not a valid port number.

% Copyright (c) 2025, The MathWorks, Inc.

    validateattributes(x, {'numeric'}, {'integer', 'scalar', '>', 0, '<', 65536}, ...
        mfilename, 'port');
end
