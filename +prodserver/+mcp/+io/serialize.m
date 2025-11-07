function marshal = serialize(marshal, variables, value)
%serialize Use persist to export MATLAB variables into multiple locations.
%
% persist is a pipeline.internal.Binding object encapsulating the
% persistence specification of this pipeline.

% Copyright (c) 2024, The MathWorks

arguments
    marshal prodserver.mcp.io.MarshallURI
    variables string
    value cell
end

    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.insertMissingFields
    import prodserver.mcp.io.parseURI

    knownVariables = marshal.variables;
    
    % variables defines names and order of value input.
    for v = 1:numel(variables)

        % If the variable is described, use the description to export it.
        % Otherwise, use the defaults.
        u = uri(marshal,variables(v));
        if isempty(u)
            u = marshal.defaults.uriprefix + variables(v);
            scheme = marshal.defaults.scheme;
        else
            uParts = parseURI(u);
            scheme = uParts.scheme;
        end
        write = marshal.symbol.persistence.schemes.(scheme).write;
        fcn = write.fcn;

        i = strcmp(knownVariables, variables(v));
        if nnz(i) == 1
            % Override defaults with the values in the description.
            d = description(marshal,variables(v));
            if hasField(d,"uri")
                u = d.uri;
            end
            if hasField(d,"write")
                write = insertMissingFields(write,d.write); 
                if hasField(write,"fcn")
                    fcn = write.fcn;
                end
            end
        end

        args = value(v); % Cell array
        if hasField(write,"config") 
            if isstruct(write.config)
                cfg = write.config;
            elseif isstring(write.config) && numel(write.config) > 1
                % config is an array of pairs of strings: 
                %     <field name>, <field value>
                % Make a structure
                for i = 1:2:numel(write.config)
                    cfg.(write.config(i)) = write.config(i+1);
                end
            else
                cfg = struct.empty;
            end

            if ~isempty(cfg)
                args = [ args, { cfg } ]; %#ok<AGROW>
            end
        end

        % If d is non-empty, it is the actual, literal, value of the
        % written data, which must be attached to the URI.
        d = feval(fcn, u, args{:});

        if ~isempty(d)
            u = u + "?" + string(d);
            marshal = set(marshal,variables(v),u);
        end
        
    end

end
