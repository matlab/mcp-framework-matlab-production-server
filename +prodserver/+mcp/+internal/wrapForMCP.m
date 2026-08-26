function [wrappers,indirect] = wrapForMCP(fcns,wrappers,folder,opts)
% wrapForMCP Generate wrapper function for deployment as an MCP tool.
% Write the wrapper function into folder. fcns and wrappers must be the
% same length. Return full paths to generated files.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        fcns { prodserver.mcp.validation.mustBeText }
        wrappers { prodserver.mcp.validation.mustBeText }
        folder { mustBeFolder }
        opts.typemap struct = [];
        opts.maxLiteralSize = prodserver.mcp.MCPConstants.MaxLiteralSize
        opts.import string = string.empty
        opts.AI = []
        opts.timeout double = 30
        opts.retry double = 2
    end

    import prodserver.mcp.MCPConstants
    
    prodserver.mcp.validation.mustBeSameSize(1,{wrappers,fcns});

    % Generate or copy wrapper for each function.
    indirect = cell(size(fcns));
    for n = 1:numel(fcns)
        % Choose wrapper generation mechanism based on wrapper value.
        if strlength(wrappers(n)) == 0 || ...
                strcmpi(wrappers(n), MCPConstants.AutoWrapper)

            isAuto = strcmpi(wrappers(n), MCPConstants.AutoWrapper);

            % Generate wrapper function from metadata available via
            % metafunction.
            [~,name] = fileparts(fcns(n));
            wrapFcn = name+MCPConstants.WrapperFileSuffix;
            try
                [code,def] = prodserver.mcp.internal.mcpWrapper(fcns(n), wrapFcn, ...
                    import=opts.import,maxLiteralSize=opts.maxLiteralSize, ...
                    typemap=opts.typemap);
            catch me
                if isAuto && ismember(me.identifier, ...
                        ["prodserver:mcp:InputArgBlockRequired", ...
                         "prodserver:mcp:OutputArgBlockRequired"])
                    % No argument blocks — cannot determine parameter
                    % sizes. Skip wrapper generation; use original function.
                    wrappers(n) = which(fcns(n));
                    copyfile(wrappers(n),folder);
                    [~,file] = fileparts(wrappers(n));
                    wrappers(n) = fullfile(folder,file+".m");
                    continue;
                end
                rethrow(me);
            end

            % Auto mode: discard the wrapper if all parameters are literal.
            if isAuto && isempty(def)
                % No externalized parameters — wrapper is unnecessary.
                wrappers(n) = which(fcns(n));
                copyfile(wrappers(n),folder);
                [~,file] = fileparts(wrappers(n));
                wrappers(n) = fullfile(folder,file+".m");
                continue;
            end

            % Name of the wrapper file to fill with the wrapper code.
            wrappers(n) = fullfile(folder,wrapFcn+".m");

            % May be empty if there are no indirect references to parameter
            % schemas.
            indirect{n} = def;

            % Will need to rehash to reference metafunction's cache if
            % we're overwriting the wrapper function.
            refreshCache = false;
            if exist(wrappers(n),"file") == 2
                refreshCache = true;
            end

            % Generated code already ends with a newline.
            writelines(code,wrappers(n),TrailingLineEndingRule="never");

            if refreshCache
                rehash;
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