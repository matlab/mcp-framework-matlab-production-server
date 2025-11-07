function values = deserialize(persist, data, variables)
%deserialize Use persistence descriptions to import data into MATLAB 
%variables.
%
% persist is a pipeline.internal.Persistence object encapsulating the
% persistence specification of this pipeline.

% Copyright (C) 2023, The MathWorks

arguments
    persist prodserver.mcp.storage.Binding
    data 
    variables string
end

    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.insertMissingFields
    import prodserver.mcp.io.parseURI

    values = cell(1,numel(variables));
    knownVariables = persist.variables;

    % variables defines names and order of value outputs.
    for v = 1:numel(variables)

        % If the variable is described, use the description to import it.
        % Otherwise, use the defaults.

        u = uri(persist,variables(v));
        if isempty(u)
            u = persist.defaults.uriprefix + variables(v);
            scheme = persist.defaults.scheme;
        else
            uParts = parseURI(u);
            scheme = uParts.scheme;
        end
        read = persist.symbol.persistence.schemes.(scheme).read;
        fcn = read.fcn;

        i = strcmp(knownVariables,variables(v));
        if nnz(i) == 1
            d = description(persist,variables(v));
            
            % Override default values with those in the description.
            if hasField(d,"uri")
                u = d.uri;
            end
            if hasField(d,"read")
                read = insertMissingFields(read,d.read);
                if hasField(read,"fcn")
                    fcn = read.fcn;
                end
            end
        end

        args = {};
        if hasField(read,"config")
            if isstruct(read.config)
                cfg = read.config;
            elseif isstring(read.config) && numel(read.config) > 1
                % Config is an array of pairs of strings:
                %     <field name>, <field value>
                % Make a structure
                for i = 1:2:numel(s.config)
                    cfg.(read.config(i)) = read.config(i+1);
                end
            else
                cfg = struct.empty;
            end

            if ~isempty(cfg)
                args = { cfg };
            end
        end

        if ~isempty(data)
            args = [ args { data } ]; %#ok<AGROW>
        end

        values{v} = feval(fcn, u, args{:});
    end

end
