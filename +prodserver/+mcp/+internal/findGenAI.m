function availableAI = findGenAI()
% findGenAI Which generative AI interfaces are available?

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.GenerativeAI
    import prodserver.mcp.MCPConstants

    % Check environment variables
    gev = keys(MCPConstants.GenAIEnvVar);
    gevI = false(size(gev));
    for n = 1:numel(gev)
        env = MCPConstants.GenAIEnvVar(gev(n));
        if isempty(getenv(env)) == false
            gevI(n) = true;
        end
    end
    availableAI = gev(gevI);
end