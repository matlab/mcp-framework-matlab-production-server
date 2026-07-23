function [varargout] = mcpHandler(varargin)

% Copyright 2025-2026 The MathWorks, Inc.

	[varargout{1:nargout}] = prodserver.mcp.internal.mcpHandler(varargin{:});
end