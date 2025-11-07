function wrappers = wrapForMCP(fcns,wrappers,folder,availableAI,timeout,retry)
% wrapForMCP Generate wrapper function for deployment as an MCP tool.
% Write the wrapper function into folder. fcns and wrappers must be the
% same length. Return full paths to generated files.

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    
    validateattributes(wrappers,["string","char","cell"], {"nonempty","vector"}, '', ...
        'wrappers',1);
    validateattributes(fcns,["string","char","cell"], {"nonempty","vector"}, '', ...
        'fcns',2);
    prodserver.mcp.validation.mustBeSameSize(1,{wrappers,fcns});

    % Generate or copy wrapper for each function.
    for n = 1:numel(fcns)
        % Choose wrapper generation mechanism if wrapper is empty.
        if strlength(wrappers(n)) == 0
            % If metafunction is not available, use GenAI, if available and
            % enabled.
            if isMATLABReleaseOlderThan("R2026a")
                if isempty(availableAI) 
                    error("prodserver:mcp:Unwrapped", ...
   "Cannot generate or find wrapper function. Set wrapper='%s' to " + ...
   "build the MCP tool without a wrapper function.", ...
                        MCPConstants.NoWrapper);
                end
                % Arbitrarily choose 1st available GenAI
                wrappers(n) = prodserver.mcp.genai.generateMCPWrapper(fcn(n), ...
                    availableAI(1),folder,timeout,retry);
            else
                % Generate wrapper function from metadata available via 
                % metafunction. 
                [~,name] = fileparts(fcns(n));
                wrapFcn = name+MCPConstants.WrapperFileSuffix;
                code = prodserver.mcp.internal.mcpWrapper(fcns(n), wrapFcn);
                wrappers(n) = fullfile(folder,wrapFcn+".m");
                writelines(code,wrappers(n));
            end
        else
            if strcmpi(wrappers(n),MCPConstants.NoWrapper) == true
                % Explicitly not generating or copying a wrapper for fcn(n).
                % fcn(n) is its own wrapper.
                wrappers(n) = which(fcns(n));
            end
            % Copy wrapper to deployment artifacts folder and adjust the 
            % wrapper's path.
            copyfile(wrappers(n),folder);
            [~,file] = fileparts(wrappers(n));
            wrappers(n) = fullfile(folder,file+".m");
        end
    end
end