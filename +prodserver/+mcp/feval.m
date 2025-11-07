function [varargout] = feval(endpoint, tool, varargin)
% feval Call Model Context Protocol tool at endpoint with variable inputs.
%
%   [varargout] = feval(endpoint, tool, varargin) calls the
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
%  Invoke "cleanSignal" tool with three required inputs:
%
%    prodserver.mcp.feval("http://localhost:9910/mcp", ...
%        "cleanSignal", noisy, frequency, clean)
%
%  Invoke "detectEdge" tool with two required and two optional inputs:
%
%    prodserver.mcp.feval("http://localhost:9910/mcp", ...
%        "detectEdge", image, edges, algorithm="Canny", aperture=7)
%    

% Copyright 2025, The MathWorks, Inc.

    arguments
        endpoint string { prodserver.mcp.validation.mustBeMCPServer }
        tool string { mustBeTextScalar }
    end
    arguments (Repeating)
        varargin
    end

    import prodserver.mcp.internal.hasField
    import prodserver.mcp.MCPConstants

    %
    % Initialize connection via JSON-RPC "initialize" message.
    %

    % Require that the server publish tools.
    [session,id] = prodserver.mcp.internal.initialize(endpoint, ...
        require="Tools");

    %
    % Check tools, to verify that TOOL exists at ENDPOINT
    %
    
    [items,id] = prodserver.mcp.internal.list(endpoint,session, ...
        "Tools",id=id);
    tools = items.tools;

    % Out, out, damn char!
    names = arrayfun(@(t)string(t.name),tools);

    found = strcmp(tool,names);
    if nnz(found) ~= 1
        error("prodserver:mcp:NonUniqueTool", "Tools must exist and " + ...
            "have unique names. Found %d tools named %s.", nnz(found), ...
            tool);
    end
    t = tools(found);

    % Validate input argument count -- not more than max or less than
    % required.
    if hasField(t,"inputSchema") == false
        error("prodserver:mcp:NoInputSchema", "Tool %s missing input " + ...
            "schema. Inform tool creator.", tool);
    end
    N = numel(varargin);
    tN = numel(fieldnames(t.inputSchema.properties));
    if N > tN
        error("prodserver:mcp:TooManyInputs", "Maximum number of inputs " + ...
            "to tool %s is %d but %d provided.", tool, tN, N);
    end
    tN = numel(t.inputSchema.required);
    if N < tN
        error("prodserver:mcp:TooFewInputs", "Tool %s requires at " + ...
            "least %d inputs but only %d provided.", tool, tN, N);
    end

    %
    % Fetch signature, required for output argument management
    % 

    sigEndpoint = replace(endpoint,MCPConstants.MCP,MCPConstants.Signature);
    sig = prodserver.mcp.internal.signature(tool,sigEndpoint,session);
    if isempty(sig)
        error("prodserver:mcp:MissingSignature", ...
            "Tool %s missing signature information. Inform tool " + ...
            "creator.", tool);
    end

    %
    % Invoke tool
    %

    data.id = id;
    data.method = "tools/call";
    data.jsonrpc = MCPConstants.jrpcVersion;
    data.params.name = tool;

    % Assume "required" lists parameters in order.
    req = string(split(t.inputSchema.required,','));
    for n = 1:numel(req)
        data.params.arguments.(req(n)) = varargin{n};
    end
    if n < numel(varargin)
        varargin = varargin(n:end);
        N = numel(varargin)/2;
        if mod(N,2) ~= 0
            error("prodserver:mcp:UnevenOptionalArguments", ...
                "Optional arguments must be name/value pairs, but " + ...
                "only an uneven number (%d) of arguments remain after " + ...
                "processing the required arguments.");
        end
        for n = 1:N
            data.params.arguments.(varargin{n*2-1}) = varargin{n*2};
        end
    end

    headers = [
        matlab.net.http.HeaderField('Content-Type', 'application/json'), ...
        matlab.net.http.HeaderField(MCPConstants.ProtocolVersion, ...
        MCPConstants.protocolVersion), ...
        matlab.net.http.HeaderField(MCPConstants.SessionId, char(session))
        ];
    body = matlab.net.http.MessageBody(data);
    request = matlab.net.http.RequestMessage('POST', headers, body);
    response = send(request,endpoint);
    prodserver.mcp.internal.requireSuccess(response,endpoint, ...
        request=data.method);

    % Require structuredContent field.
    if hasField(response,"Body.Data.result.structuredContent") == false
        error("prodserver:mcp:NoStructuredContent", "Call to tool %s " + ...
            "did not produce expected structured content.", ...
            tool);
    end

    % Result is "structuredContent". Return the outputs as a cell
    % array. Order by output schema if available.
    result = response.Body.Data.result.structuredContent;
    req = string.empty;
    if hasField(t,"outputSchema.required")
        req = string(t.outputSchema.required);
    end
    if hasField(sig,tool+".output")
        req = union(req,string(sig.(tool).output.name),"stable");
    end
    if ~isempty(req)
        req = string(req);
        varargout = cell(1,nargout);
        for n=1:nargout
            varargout{n} = result.(req(n));
        end
    elseif nargout > 0
        error("prodserver:mcp:TooFewOutputs",...
            "Too few outputs. %d requested. %d received from %s.", ...
            nargout, numel(req), endpoint);
    end

    if n < numel(result)
        % Create name/value pairs from the remaining (non-required)
        % outputs and add them to the end of varargout.
        if exist("req","var")
            result = rmfield(result,req);
        end
        names = fieldnames(result);
        values = cellfun(@(n)results.(n),names);
        optOut = [names;values]; optOut = optOut{:};

        varargout = [ varargout, optOut ];
    end

    %
    % Terminate session
    %

    % No response expected.
    prodserver.mcp.internal.terminate(endpoint,session);

end
