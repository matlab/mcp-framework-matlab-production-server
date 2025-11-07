function cfg = findConfig(config,u,type)
%findConfig Search config for a structure matching the importable or
%exportable data format described in the parsed URI u.

% Copyright (c) 2024 The MathWorks, Inc.

    
    import prodserver.mcp.internal.hasField

    if isstring(type) || ischar(type)
        if strcmpi(type,"table") == false && strcmp(type,"any") == false
            type = "matrix";
        end
    elseif endsWith(class(type),"ImportOptions")
        % An importOptions object. If the data starts on line 1 and all the
        % variables are the same type, readmatrix. Otherwise, readtable.
        types =  type.VariableTypes;
        firstDataLine = findDataStart(type);
        if isscalar(unique(types)) && firstDataLine == 1
            type = "matrix";
        else
            type = "table";
        end
    end

    switch u.scheme
        case "file"
            if hasField(config,"config"), config = config.config; end
            [~,~,ext] = fileparts(u.path);
            ext = extractAfter(ext,".");
            found = false(size(config));
            for n = 1:numel(config)
                candidates = split(config(n).ext,",");
                found(n) = any(matches(candidates,ext));
            end

            if nnz(found) > 1 && nargin == 3 && strcmp(type,"any") == false
                config = config(found);
                found = matches([config.type],type);
            end
 
        case "literal"
           found = 1;

        case "kafka"
            found = 1; 

        otherwise
            found = 1;

    end

    if nnz(found) > 1
        m = join(candidates(found),",");
        error("prodserver:mcp:AmbiguousStorageFormat", ...
"Unable to import or export %s with format %s because it matches " + ...
"multiple serialization formats: %s.", u.path,ext,m);
    elseif nnz(found) == 1
        cfg = config(found);
    elseif isscalar(config) 
        cfg = config;
    else
        error("prodserver:mcp:Contraband",...
"Unable to import or export variable %s because data format %s " + ...
"is unrecognized.",u.path,ext);
    end

end

function n = findDataStart(opts)
    n = -1;
    cls = class(opts);
    if endsWith(cls,"SpreadsheetImportOptions")
        n = opts.DataRange;
        if isstring(n) && (double(n) == 1 || strcmpi(n,'a1'))
            n = 1;
        end
    elseif endsWith(cls,"DelimitedTextImportOptions") || ...
        endsWith(cls,"FixedWidthImportOptions")
        n = opts.DataLines;
    end      
end
