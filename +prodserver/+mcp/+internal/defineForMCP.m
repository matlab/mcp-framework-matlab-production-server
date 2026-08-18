function definition = defineForMCP(tools,fcns, opts)
% Create a single MCP tool definition structure for one or more MCP tools.
% Use metafunction (R2026a and later) or generative AI to create MCP tool
% definition from the text in each function's file. tools, fcns and
% definitions may be vectors, but they must always be the same size, unless
% definitions is empty. (tools and fcns must ALWAYS be the same size.)

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        % Name of the tool on the MCP server
        tools string { prodserver.mcp.validation.mustBeText }
        % Function called by the tool. Must be on the MATLAB path.
        fcns string { prodserver.mcp.validation.mustBeText }
        opts.AI = [];
        % If non-empty, the definition(s) of tools
        opts.definitions cell = {};
        % Wire encoding to use for each tool.
        opts.encoding prodserver.mcp.WireEncoding = "Invertible";
        % Map of MATLAB to JSON types. Fieldnames are MATLAB types, field
        % values are JSON types.
        opts.typemap struct = [];
        % Schema objects to embed in $defs of generated definition.
        opts.defs cell = {}
        % At what stage of the build is defineForMCP being called?
        opts.stage prodserver.mcp.BuildStage = "Definition"
    end

    % Position-based error only makes sense in argument block.
    prodserver.mcp.validation.mustBeSameSize(["fcns","tools"],tools,fcns);
    if ~isempty(opts.defs)
        prodserver.mcp.validation.mustBeSameSize(["defs", "tools"],...
            tools,opts.defs);
    end

    % Cannot provide both opts.definitions and opts.defs
    if ~isempty(opts.defs) && ~isempty(opts.definitions)
        error("prodserver:mcp:DoubleDefinition", "Cannot provide both " + ...
            "definitions and defs arguments. If providing definitions, " + ...
            "include any required defs in definitions.")
    end
    
    definition.tools = {};
    for n = 1:numel(tools)
        if isempty(opts.definitions) || isempty(opts.definitions{n})
            defs = [];
            if ~isempty(opts.defs)
                defs = opts.defs{n};
            end
            if isscalar(opts.encoding) 
                encoding = opts.encoding; 
            else
                encoding = opts.encoding(n);
            end
            td = prodserver.mcp.internal.mcpDefinition(tools(n), ...
                fcns(n),typemap=opts.typemap,defs=defs,stage=opts.stage,...
                encoding=encoding);
        else
            % Assume each of these is a complete description of a single 
            % tool. Add the "tools" value to the definition we're building.
    
            if isstruct(opts.definitions{n})
                td = opts.definitions{n};
            elseif exist(opts.definitions{n},"file") == 2
                td = jsondecode(fileread(opts.definitions{n}));
            elseif isstring(opts.definitions{n})
                td = jsondecode(opts.definitions{n});
            end
        end
    
        % MCP tool JSON expects tools field to have an array value,
        % even if there is only one tool. The only way to ensure
        % that is to place the tool description in a cell array.
        % Which is a good idea anyway because the structures won't
        % be identical even at the highest level, so might not
        % concatenate.
        %
        % signatures is not an array -- it's a structure with fieldnames
        % equal to the names of the tools. So copy the signature data by
        % field name.
        if iscell(td.tools)
            definition.tools = [definition.tools, td.tools];
        elseif isstruct(td.tools)
            definition.tools{n} = td.tools;
        end
        for f = string(fieldnames(td.signatures))'
            definition.signatures.(f) = td.signatures.(f);
        end
    end
    % Returned definition must be a MATLAB structure decoded from a 
    % JSON string.
end