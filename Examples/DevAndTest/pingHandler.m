function [varargout] = pingHandler(varargin)
	[varargout{1:nargout}] = prodserver.mcp.internal.pingHandler(varargin{:});
end