classdef tschema < matlab.unittest.TestCase

% Copyright 2025-2026 The MathWorks, Inc.

    properties
        % Map of MATLAB types to JSON types. Specified as key/value pairs:
        % <MATLAB>,<JSON>.
        typemap = dictionary(...
            "uint8", "integer", "int8", "integer",...
            "uint16", "integer", "int16", "integer", ...
            "uint32", "integer", "int32", "integer", ...
            "uint64", "integer", "int64", "integer", ...
            "float", "number", "double", "number", ...
            "char", "string", "string", "string" ... 
        );

        tempFolder
    end

    methods

        function type = schemaFromValue(test, value)

            if isstruct(value)
                type.type = "object";
                fields = string(fieldnames(value))';
                type.required = fields;
                for f = fields
                    type.properties.(f) = schemaFromValue(test,value.(f));
                end

            elseif iscell(value)
                type.type = "array";
                type.items = cellfun(@(v)schemaFromValue(test,v), ...
                    value,UniformOutput=false);
                type.minItems = numel(value);
                type.maxItems = numel(value);
            else
                if isKey(test.typemap,class(value))
                    type.type = test.typemap(class(value));
                else
                    type.type = class(value);
                end
            end

        end

        function params = addVariableToParameters(test,params,var,value,array)

            params.required = [params.required, {var}];
            params.properties.(var) = schemaFromValue(test,value);
            if array
                % Move type into "items" field, change type to "array"
                params.properties.(var).items.type = ...
                    params.properties.(var).type;
                params.properties.(var).type = "array";
            end
        end
    end

    methods(Test)

        function primitiveTypes(test)
            import prodserver.mcp.validation.mustMatchSchema
            import prodserver.mcp.MCPConstants
    
            tool = "grapplingSaw";
            d.name = tool;
            d.description = "A saw that grapples";
            d.inputSchema.type = "object";
            d.inputSchema.required = {};
            
            value = { uint8(17), int8(17), uint16(17), int16(17), ...
                uint32(17), int32(17), uint64(17), int64(17), ...
                single(17.81), double(17.81), 'MATLAB''s most annoying type', ...
                "character assassination"};
            var = "in" + string(1:numel(value));
            
            for n = 1:numel(value)
                d.inputSchema = addVariableToParameters(test,...
                    d.inputSchema,var(n),value{n},false);
            end
            td.(MCPConstants.DefinitionVariable).tools = {d};

            % Expect no error
            for n = 1:numel(value)
                mustMatchSchema(value{n},var(n),td,tool,"input");
            end

        end

        function arrayTypes(test)
            import prodserver.mcp.validation.mustMatchSchema
            import prodserver.mcp.MCPConstants

            tool = "grapplingSaw";
            d.name = tool;
            d.description = "A saw that grapples";
            d.inputSchema.type = "object";
            d.inputSchema.required = {};

            % Do not include char, because array of char is an unreasonable
            % JSON type -- array of string is OK, but array of char is not
            % supported.
            scalarValue = { uint8(17), int8(17), uint16(17), int16(17), ...
                uint32(17), int32(17), uint64(17), int64(17), ...
                single(17.81), double(17.81), ...
                "character assassination"};
            var = "in" + string(1:numel(scalarValue));

            % Set array = true to create a schema that expects arrays (of
            % which scalars are a degenerative type).
            for n = 1:numel(scalarValue)
                d.inputSchema = addVariableToParameters(test,...
                    d.inputSchema,var(n),scalarValue{n},true);
            end
            td.(MCPConstants.DefinitionVariable).tools = {d};

            % Expect no error for scalars
            for n = 1:numel(scalarValue)
                mustMatchSchema(scalarValue{n},var(n),td,tool,"input");
            end

            % Expect no error for scalars
            arrayValue = cell(size(scalarValue));
            for n = 1:numel(arrayValue)
                rows = randi(5);
                cols = randi(5);
                arrayValue{n} = createArray(rows,cols,...
                    FillValue=scalarValue{n});
            end

            % Expect no error for arrays
            for n = 1:numel(scalarValue)
                mustMatchSchema(arrayValue{n},var(n),td,tool,"input");
            end 
        end

        function requiredErrors(test)
            import prodserver.mcp.validation.mustMatchSchema
            import prodserver.mcp.MCPConstants

            tool = "grapplingSaw";
            d.name = tool;
            d.description = "A saw that grapples";
            d.inputSchema.type = "object";
            d.inputSchema.required = {};

            value = { uint8(17), int8(17), uint16(17), int16(17), ...
                uint32(17), int32(17), uint64(17), int64(17), ...
                single(17.81), double(17.81), 'MATLAB''s most annoying type', ...
                "character assassination"};
            var = "in" + string(1:numel(value));

            for n = 1:numel(value)
                d.inputSchema = addVariableToParameters(test,...
                    d.inputSchema,var(n),value{n},false);
            end
            td.(MCPConstants.DefinitionVariable).tools = {d};

            % Expect error because we're deliberately passing a bad value.
            badValue = test;
            for n = 1:numel(value)
                test.verifyError(...
    @(v)mustMatchSchema(badValue,var(n),td,tool,"input"),...
                    "prodserver:mcp:SchemaValidationFailed");
            end
        end

        function containers(test)
            import prodserver.mcp.validation.mustMatchSchema
            import prodserver.mcp.MCPConstants

            % Simple structure
            s.x = 13; s.y = 14; s.z = 15;

            % Structure of heterogeneous structures
            ss.one = s;
            ss.two.pi = 3.14;
            ss.two.phi = 1.1618;
            ss.two.e = 2.718;
            ss.three.name = "Mu Cephei";
            ss.three.ra.value = 325.877;
            ss.three.ra.unit = "degrees";
            ss.three.dec.value = 58.780046;
            ss.three.dec.unit = "degrees";

            % Cellstr
            cs = {'A', 'plague', 'on', 'both', 'your', 'houses'};

            % Heterogeneous cell array
            ca = { s, 'A cheery little quote.', "carpe meteoron", ...
               1796, cs };

            value = { s, ss, cs, ca };
            var = "in" + string(1:numel(value));

            tool = "grapplingSaw";
            d.name = tool;
            d.description = "A saw that grapples";
            d.inputSchema.type = "object";
            d.inputSchema.required = {};

            for n = 1:numel(value)
                d.inputSchema = addVariableToParameters(test,...
                    d.inputSchema,var(n),value{n},false);
            end
            td.(MCPConstants.DefinitionVariable).tools = {d};

            % Expect no errors
            for n = 1:numel(value)
                mustMatchSchema(value{n},var(n),td,tool,"input");
            end 

            % Walk down the value array backwards, expecting errors all
            % along the way.
            for n = 1:numel(value)
                test.verifyError(...
                    @()mustMatchSchema(value{numel(value)+1-n},var(n),td,...
                       tool,"input"),...
                    "prodserver:mcp:SchemaValidationFailed");
            end 

        end

    end

end