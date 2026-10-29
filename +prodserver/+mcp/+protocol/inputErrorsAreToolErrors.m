function tf = inputErrorsAreToolErrors(version)
%inputErrorsAreToolErrors Does this revision report bad tool arguments as a
%tool execution error?
%   tf = inputErrorsAreToolErrors(version) is true if a tools/call whose
%   arguments fail the tool's inputSchema gets result.isError under the
%   protocol revision VERSION, and false if it gets JSON-RPC error -32602.
%   Each revision's adapter declares its rule as InputErrorsAreToolErrors;
%   an unsupported revision is an error,
%   prodserver:mcp:UnsupportedProtocolVersion.

% Copyright 2026 The MathWorks, Inc.

    arguments
        version (1,1) string
    end

    tf = prodserver.mcp.protocol.ProtocolRegistry.instance().lookup( ...
        version).InputErrorsAreToolErrors;
end
