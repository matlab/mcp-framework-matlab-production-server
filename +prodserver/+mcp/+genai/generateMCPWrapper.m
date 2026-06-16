function wrapper = generateMCPWrapper(fcn,genAI,folder,timeout,retry)
% generateMCPWrapper Use the chosen generative AI interface to create a
% wrapper function for fcn.

% Copyright 2025, The MathWorks, Inc.
    
    genFcn = "prodserver.mcp.genai." + lower(string(genAI)) + "MCPWrapper";
    w = which(genFcn);
    if isempty(w)
        error("prodserver:mcp:NoGeneratorFcn", ...
            "No generator function for %s: %s does not exist.", ...
            genAI, genFcn);
    end

    wrapper = feval(genFcn,fcn,genAI,folder,timeout,retry);
    
end