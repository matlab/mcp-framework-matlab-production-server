function x = cast(type, x, opts)
%cast Cast X to TYPE. TYPE may be a MATLAB primitive type or class name.
%This function will raise an exception if requested type conversion is not
%possible.

% Copyright 2026 The MathWorks, Inc.

    arguments
        type string
        x
        opts.schema string = ""
    end
    
    import prodserver.mcp.internal.Constants

    if type == "struct" && ~isa(x, "struct") && opts.schema == ""
        error("prodserver:mcp:StructCastRequiresSchema", ...
            "Conversion to struct type requires schema.");
    end

    try
        if isa(x,type) == false
            if nnz(strcmp(type,Constants.castType)) == 1
                x = cast(x, type);
            elseif exist(type,"class") || ismember(type, ["cell" "struct"])
                switch type
                    case "cell"
                        x = num2cell(x);
                    case "struct"
                        % Schema-based struct conversion (schema validated above)
                    case "function_handle"
                        x = str2func(x);
                    otherwise
                        x = feval(type,x);
                end
            end
        end

    catch me
        error("prodserver:mcp:TypeConversionFailure", ...
            "Cannot convert variable of type %s to type %s: %s", ...
            class(x), type, me.message);
    end
end
