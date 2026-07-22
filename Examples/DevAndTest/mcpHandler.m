function [varargout] = mcpHandler(varargin)
	[varargout{1:nargout}] = prodserver.mcp.internal.mcpHandler(varargin{:});
end