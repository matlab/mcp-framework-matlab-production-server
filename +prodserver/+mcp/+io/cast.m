function x = cast(type, x, opts)
%cast Cast X to TYPE. TYPE may be a MATLAB primitive type or class name.
%This function will raise an exception if requested type conversion is not
%possible.

% Copyright 2026, The MathWorks, Inc.

    arguments
        type string
        x
        opts.schema string = ""
    end
    
    import prodserver.mcp.internal.Constants

    try
        if isa(x,type) == false
            if nnz(strcmp(type,Constants.castType)) == 1
                x = cast(x, type);
            elseif exist(type,"class")
                switch type
                    case "cell"
                        % Convert to cell array
                        x = num2cell(x);
                    case "struct"
                        if isempty(opts.schema)
                            error("prodserver:mcp:StructCastRequiresSchema", ...
                                "Conversion to struct type requires schema.");
                        end
                    case "function_handle"
                        x = str2func(x);
                    otherwise
                        % Call class constructor -- may fail if conversion not
                        % supported.
                        x = feval(type,x);
                end
            end
        end

    catch me
        error("prodserver:MCP:TypeConversionFailure", ...
            "Cannot convert variable of type %s to type %s: %s", ...
            class(x), type, me.message);
    end
end
