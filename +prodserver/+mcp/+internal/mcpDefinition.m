function definition = mcpDefinition(tool,fcn,opts)
%mcpDefinition Generate a definition for tool from the code in fcn.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments(Input)
        tool (1,1) string  % Name of the tool on the MCP server.
        fcn (1,1) string   % Function the tool calls. Must be on the MATLAB path.
        opts.encoding (1,1) prodserver.mcp.WireEncoding = "Invertible";
        opts.typemap struct {mustBeScalarOrEmpty} = []
        opts.defs struct {mustBeScalarOrEmpty} = []
        opts.stage (1,1) prodserver.mcp.BuildStage = "Definition"
    end

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.parameterDescription    

    if exist(fcn,"file") == false
        error("prodserver:mcp:ToolFcnNotFound", "MCP function %s " + ...
            "not found.", fcn);
    end

    mf = prodserver.mcp.internal.metafunction(fcn);

    if isempty(mf)
        error("prodserver:mcp:CannotParseToolFcn", "Cannot parse MCP " + ...
            "function file %s. Verify that the file contains at least one " + ...
            "MATLAB function.", fcn);
    end

    %
    % MCP Tool Description
    % 

    definition.tools.name = tool;

    % Tool description from function comments (shared with SchemaObserver).
    desc = prodserver.mcp.internal.toolDescription(mf);
    if desc == string(mf.Name)
        error("prodserver:mcp:EmptyToolDescription", "Empty tool " + ...
            "description for %s. Add descriptive comment to %s following " + ...
            "the function line.", fcn, mf.FullPath);
    end
    if opts.encoding == prodserver.mcp.WireEncoding.Invertible
        if ~contains(desc, MCPConstants.WireEncodingResourceURI)
            desc = desc + " " + char(MCPConstants.WireEncodingRequiredMsg);
        end
    else
        desc = erase(desc, " " + char(MCPConstants.WireEncodingRequiredMsg));
    end
    definition.tools.description = desc;

    % MPS mapping of tool name to callable MATLAB function
    definition.signatures.(tool).function = mf.Name;
    definition.signatures.(tool).encoding = string(opts.encoding);

    % Heuristic searching about for comments that describe each input and
    % output argument.
    [in,out,inHasNVP] = parameterDescription(mf);

    % Enumerate externalized inputs and outputs
    externalIn = string.empty; 
    externalOut = string.empty;
    if ~isempty(opts.defs)
        if hasField(opts.defs,"inputSchema")
            externalIn = fieldnames(opts.defs.inputSchema);
        end
        if hasField(opts.defs,"outputSchema")
            externalOut = fieldnames(opts.defs.outputSchema);
        end
    end

    % Define inputs
    definition = defineParameters(definition,tool,"input",in, ...
        mf.Signature.Inputs,opts.typemap,opts.stage,opts.encoding,...
        externalIn);
 
    % Define outputs
    definition = defineParameters(definition,tool,"output",out, ...
        mf.Signature.Outputs,opts.typemap,opts.stage,opts.encoding, ...
        externalOut);

    % Add $defs to the definition. Since the definition is a structure,
    % we can't use $defs as a field name, as it is not a valid MATLAB
    % variable name. (This will require fix-up when description is returned
    % as JSON from server.)
    if ~isempty(opts.defs)
        definition.tools.(MCPConstants.DefsField) = opts.defs;
        if hasField(opts.defs,"outputSchema")
            external = fieldnames(opts.defs.outputSchema);
            for n = 1:numel(external)
                definition.tools.inputSchema.properties.(external{n}).writeOnly = true;
            end
        end
    end

    % Remove annotations in the parameter definitions of the description.
    % We use them internally to manage some wire-encoding decisions, but
    % they apparently confuse Claude, so we remove them here.
    %definition = prodserver.mcp.internal.removeField(definition,"annotation");
end

function definition = defineParameters(definition,tool,io,descriptions, ...
    signature,typemap,stage,encoding,external)
% Define a set of parameters, either input or output. Use introspection to
% collect parameter names and types. metafunction doesn't support parameter
% descriptions yet so they are extracted using a heuristic process.
%
%  definition: Structure capturing all knowledge about the tool. This
%      function adds information about parameters.
%  tool: Name of the tool.
%  io: "input" or "output" -- the group of parameters we're processing.
%  descriptions: Parameter descriptions extracted from function text.
%  signature: metafunction data on the group of parameters.
%  typemap: Maps "extra" MATLAB types to JSONRPC types. A structure.
%  stage: Stage of the build process.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.ParameterKind
    import prodserver.mcp.jsonrpc.argumentDeclaration
    import prodserver.mcp.jsonrpc.explainWireEncoding
    import prodserver.mcp.jsonrpc.argumentSchema

    % Set schema name based on parameter group -- input or output.
    if strcmp(io,"input")
        schemaName = "inputSchema";
    elseif strcmp(io,"output")
        schemaName = "outputSchema";
    end

    % User-specified schema data may be present in the description. Extract
    % it from the comments and insert it into the descriptions structure.
    % Also inject a comment explaining how to manage the wire encoding.
    if ~isempty(descriptions)
        descriptions = argumentSchema(descriptions);
        if encoding == prodserver.mcp.WireEncoding.Invertible
            descriptions = explainWireEncoding(descriptions,io,external);
        end
    end

    % Collect argument information from metafunction data.
    [parameters,required,kind,order,group,validation,default] = ...
        argumentDeclaration(signature,descriptions,encoding,stage);
    
    % Populate MATLAB signature structure with MATLAB native types.
    if ~isempty(parameters)
        [name,type] = mpsArguments(parameters);
        definition.signatures.(tool).(io).name = name;
        definition.signatures.(tool).(io).type = type;
        definition.signatures.(tool).(io).kind = kind;
        definition.signatures.(tool).(io).order = order;
        definition.signatures.(tool).(io).group = group;
        definition.signatures.(tool).(io).validation = validation;
        definition.signatures.(tool).(io).default = default;
    end

    % Convert MATLAB types to compatible JSON types
    parameters = mcpArgumentTypes(parameters,typemap);
    
    % Description of parameters
    definition.tools.(schemaName).type = "object";
    if isempty(fieldnames(parameters)) == false
        definition.tools.(schemaName).properties = parameters;
        definition.tools.(schemaName).required = required;
        [minArgs, maxArgs] = ParameterKind.NargRange(kind);
        definition.tools.(schemaName).minProperties = minArgs;
        definition.tools.(schemaName).maxProperties = maxArgs;
    end
    % Ideally we'd add this, but some LLMs (Gemini!) choke on the
    % "additionalProperties" field.
    %definition.tools.(schemaName).additionalProperties = false;
end

function pt = parameterTypeName(param,name)
% Get or set parameter type name. 
%    pt = parameterTypeName(param)      : Get name of parameter's type
%        Returns existing name.
%
%    pt = parameterTypeName(param,name) : Set name of parameter's type
%        Returns modified parameter structure.

    import prodserver.mcp.MCPConstants

    % The location of the actual type of the parameter depends on the wire
    % encoding. If we're using the invertible encoding, the type is in the
    % properties sub-structure of the wrapper. Surface it. Use the
    % annotation field to determine if we're using the invertible encoding.
    % The contains test is looking for text in the
    % wireEncodingArgTemplate.json. So if you change that, change this.
   
    wireEncoding = false;
    if isfield(param,"annotation") && ...
            contains(param.annotation,"Invertible wire encoding")
        wireEncoding = true;
    end

    if nargin == 1

        % Remove wireEncoding wrapper, because we're looking for the actual
        % type, the wrapped type, not the wrapper type.
        if wireEncoding
            type = param.properties.data;
        else
            type = param;
        end

        % type will be simple string for scalar parameters and a
        % structure for array parameters. Return the type name of the
        % elements of the array or the scalar type name.
        if strcmpi(type.type,MCPConstants.Array)
            pt = type.items.type;
        else
            pt = type.type;
        end
    else
        if wireEncoding
            if strcmpi(param.properties.data.type,MCPConstants.Array)
                param.properties.data.items.type = name;
            else
                param.properties.data.type = name;
            end
        else
            if strcmpi(param.type,MCPConstants.Array)
                param.itmes.type = name;
            else
                param.type = name;
            end
        end
        pt = param;
    end
end

function [name,type] = mpsArguments(schema)
    name = string(fieldnames(schema));
    type = arrayfun(@(i)string(parameterTypeName(schema.(i))), name);
end

function parameters = mcpArgumentTypes(parameters,typemap)
% Final adjustment to create MCP-compatible schema. 

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.SchemaOrigin
    import prodserver.mcp.jsonrpc.jsonParameterType

    name = string(fieldnames(parameters));
    for n = 1:numel(name)
        % Find the type name for this parameter.
        t = parameterTypeName(parameters.(name(n)));

        switch parameters.(name(n)).schema.origin
            case SchemaOrigin.Introspection
                % Expect MATLAB type
                t = jsonParameterType(t,typemap);
            case SchemaOrigin.Hybrid
                % Allow MATLAB or JSON type
                if prodserver.mcp.validation.isJsonSchemaType(t) == false
                    t = jsonParameterType(t,typemap);
                end
            case SchemaOrigin.Client
                % Require JSON type.
                prodserver.mcp.validation.mustBeJsonSchemaType(t);
        end

        % Remove the schema field because it is not part of the JSON
        % schema. Take the schema out of the schema. :-)
        parameters.(name(n)) = rmfield(parameters.(name(n)),"schema");

        if isempty(t) || strlength(t) == 0
            badType = parameterTypeName(parameters.(name(n)));
            error("prodserver:mcp:IncompatibleArgumentType", ...
                "Parameter '%s' has unsupported MATLAB type '%s'. Valid " + ...
                "types include numeric types, strings, cell arrays and " + ...
                "structures.", name(n), badType);
        end

        % Array and scalar have different representation. And wireEncoding
        % stores the type name in a more complex structure. So defer to a
        % method that knows all about the structure.
        parameters.(name(n)) = parameterTypeName(parameters.(name(n)),t);
    end
end

