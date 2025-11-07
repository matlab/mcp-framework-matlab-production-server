function redAlert(id, varargin)
% redAlert Report an internal error.

% Copyright 2025, The MathWorks, Inc.
    error("prodserver:mcp:internal:"+id, varargin{:});
end
