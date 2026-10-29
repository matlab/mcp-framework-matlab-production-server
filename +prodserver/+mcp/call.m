function [varargout] = call(endpoint, tool, varargin)
% call Call Model Context Protocol tool at endpoint with variable inputs.
%
%   [varargout] = call(endpoint, tool, varargin) calls the
%   named TOOL hosted at the MCP server at ENDPOINT, passing all the
%   input arguments in VARARGIN. Output arguments are returned in
%   VARARGOUT.
%
%   Inputs may be required or optional. Required arguments are positional
%   (order matters) while optional arguments are order-independent
%   name/value pairs.
%
% Examples:
%
%  Invoke "cleanSignal" tool with two required inputs and an optional
%  output location:
%
%    prodserver.mcp.call("http://localhost:9910/cleanSignal/mcp", ...
%        "cleanSignal", noisy, period, cleanURL=clean)
%
%  Invoke "detectEdge" tool with two required and two optional inputs:
%
%    prodserver.mcp.call("http://localhost:9910/edges/mcp", ...
%        "detectEdge", image, edges, algorithm="Canny", aperture=7)
%

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        endpoint string { prodserver.mcp.validation.mustBeMCPServer }
        tool string { mustBeTextScalar }
    end
    arguments (Repeating)
        varargin
    end

    % doCall returns its outputs as one cell array rather than through
    % varargout, so that a call made as a statement (nargout 0) still gets
    % its first output in ans.
    try
        varargout = doCall(endpoint, tool, nargout, varargin{:});
    catch me
        if prodserver.mcp.protocol.isProtocolError(me)
            prodserver.mcp.client.Adapter.create(endpoint, action="clear");
            varargout = doCall(endpoint, tool, nargout, varargin{:});
        else
            rethrow(me);
        end
    end
end

function outputs = doCall(endpoint, tool, nout, varargin)

    import prodserver.mcp.internal.hasField
    import prodserver.mcp.MCPConstants

    client = prodserver.mcp.client.Adapter.create(endpoint, ...
        protocol="discover");
    client.connect(require="Tool");
    cleanup = onCleanup(@()client.disconnect()); %#ok<NASGU>

    items = client.list("Tool");
    tools = items.tools;

    if isstruct(tools)
        tools = num2cell(tools);
    end

    names = cellfun(@(t)string(t.name), tools);

    found = strcmp(tool, names);
    if nnz(found) ~= 1
        error("prodserver:mcp:NonUniqueTool", "Tools must exist and " + ...
            "have unique names. Found %d tools named %s.", nnz(found), ...
            tool);
    end
    t = tools(found);
    if iscell(t)
        t = t{1};
    end

    if hasField(t, "inputSchema") == false
        error("prodserver:mcp:NoInputSchema", "Tool %s missing input " + ...
            "schema. Inform tool creator.", tool);
    end

    N = numel(varargin);
    if hasField(t.inputSchema, "maxProperties")
        tN = t.inputSchema.maxProperties;
    else
        tN = N;
    end
    if N > tN
        error("prodserver:mcp:TooManyInputs", "Maximum number of inputs " + ...
            "to tool %s is %d but %d provided.", tool, tN, N);
    end

    if hasField(t.inputSchema, "minProperties")
        tN = t.inputSchema.minProperties;
    else
        tN = numel(prodserver.mcp.internal.requiredNames(t, "inputSchema"));
    end
    if N < tN
        error("prodserver:mcp:TooFewInputs", "Tool %s requires at " + ...
            "least %d inputs but only %d provided.", tool, tN, N);
    end

    %
    % Fetch signature, required for optional and output argument management
    %

    sigEndpoint = replace(endpoint, MCPConstants.MCP, MCPConstants.Signature);
    sig = prodserver.mcp.internal.signature(tool, sigEndpoint, client);
    if isempty(sig)
        error("prodserver:mcp:MissingSignature", ...
            "Tool %s missing signature information. Inform tool " + ...
            "creator.", tool);
    end

    % As toolsCall encodes the inputs.
    encoding = prodserver.mcp.jsonrpc.toolEncoding(tool, sig=sig, def=t);

    %
    % Invoke tool
    %

    data = prodserver.mcp.jsonrpc.toolsCall(tool, client.nextId(), ...
        t, sig, varargin{:});

    response = client.send(data, label=data.method + " " + tool);

    outputs = prodserver.mcp.internal.assembleOutputs(tool, endpoint, ...
        t, sig, response.Body.Data, nout, encoding);
end
