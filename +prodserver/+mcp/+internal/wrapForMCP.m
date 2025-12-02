function wrappers = wrapForMCP(fcns,wrappers,folder,opts)
% wrapForMCP Generate wrapper function for deployment as an MCP tool.
% Write the wrapper function into folder. fcns and wrappers must be the
% same length. Return full paths to generated files.

% Copyright 2025, The MathWorks, Inc.

    arguments
        fcns { prodserver.mcp.validation.mustBeText }
        wrappers { prodserver.mcp.validation.mustBeText }
        folder { mustBeFolder }
        opts.import string = string.empty
        opts.AI = []
        opts.timeout double = 30
        opts.retry double = 2
    end

    import prodserver.mcp.MCPConstants
    
    prodserver.mcp.validation.mustBeSameSize(1,{wrappers,fcns});

    % Generate or copy wrapper for each function.
    for n = 1:numel(fcns)
        % Choose wrapper generation mechanism if wrapper is empty.
        if strlength(wrappers(n)) == 0

            % Generate wrapper function from metadata available via
            % metafunction.
            [~,name] = fileparts(fcns(n));
            wrapFcn = name+MCPConstants.WrapperFileSuffix;
            code = prodserver.mcp.internal.mcpWrapper(fcns(n), wrapFcn, ...
                import=opts.import);
            wrappers(n) = fullfile(folder,wrapFcn+".m");
            % Generated code already ends with a newline.
            writelines(code,wrappers(n),TrailingLineEndingRule="never");
            
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