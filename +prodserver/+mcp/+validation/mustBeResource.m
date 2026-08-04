function mustBeResource(x)
% Error if not a structure with a uri and contents. Either contents or
% reference permitted, not both. Other fields optional. 
%    uri        : Unique name of the resource. Must be URL format.
%    contents   : Literal content or path to file containing content 
%    reference  : URL read by marshaller or import function
%    name       : Display name of the resource
%    description: Description of the resource
%    mimeType   : Type of resource contents
%    title      : Display title of the resource
%    import     : ImportOptions object or function handle
%
% Using a structure instead of an object to simplify conversion
% to/from JSON.

% Copyright 2026-2026 The MathWorks, Inc.

     for n = 1:numel(x)
        if isstruct(x)
            r = x(n);
        elseif iscell(x)
            r = x{n};
        else
            error("prodserver:mcp:InvalidResource", ...
                "Resource list must be structure or cell array, not %s.", ...
                class(x));
        end
    
        try
            validateResource(r);
        catch me
            if isscalar(x)
                rethrow(me);
            else
                error(me.identifier, ...
                    "Element %d of resource list invalid: '%s'", ...
                    n, me.msg);
            end
        end
     end
end

function validateResource(x)
    persistent fieldType optionalFields fields contentFields requiredFields
    if isempty(fieldType)
        requiredFields = { 'uri' };
        contentFields = {'contents', 'reference'};

        % Valid types for these fields
        fieldType.content = ["text", "function_handle"];
        fieldType.import = ["matlab.io.ImportOptions", "function_handle"];

        % These are the only permitted optional fields.
        optionalFields = {'name', 'description', 'mimeType', ...
            'title', 'import'};
        fields = [ requiredFields, optionalFields, contentFields ];
    end

    if isstruct(x)
        % Check if the structure has the required fields
        if all(isfield(x, requiredFields)) 
            if nnz(isfield(x,contentFields)) == 1

                % Only the defined optional files are allowed.
                f = setdiff(fieldnames(x),[requiredFields,contentFields]);
                if ~all(ismember(f,optionalFields))
                    badF = setdiff(f,optionalFields);
                    error("prodserver:mcp:InvalidResourceField", ...
          'Resource structure contains invalid optional fields: %s', ...
                        strjoin(badF, ', '));
                end

                % Check type of existing fields. 
                for i = 1:length(fields)
                    if isfield(x, fields{i})

                        % Allow "text" as a class name, because it should
                        % be. It means "string", "char", or "cellstr".
                        type = "text";
                        if isfield(fieldType, fields{i})
                            type = fieldType.(fields{i});
                        end

                        badTypeId = "prodserver:mcp:InvalidResourceFieldType";
                        badTypeMsg = 'Field %s must contain value of type %s not type %s';

                        % Does this field have any of the valid field
                        % types? Exit the loop as soon as a valid type
                        % detected. for/while? Both are annoying. while
                        % requires manual index increment, for requires
                        % manual exit. 
                        validType = false;
                        for t = 1:numel(type)
                            if type(t) == "text"
                                if prodserver.mcp.validation.istext(x.(fields{i})) == false
                                    error(badTypeId, badTypeMsg, fields{i}, type(t), class(x.(fields{i})));
                                end
                                validType = true;
                            else
                                if isa(x.(fields{i}),type(t))
                                    validType = true;
                                end
                            end
                            if validType, break; end
                        end
                        if validType == false
                            error(badTypeId, badTypeMsg, fields{i}, ...
                                strjoin(type,", "), class(x.(fields{i})));
                        end
                    end
                end
            elseif ~isempty(x)
                error("prodserver:mcp:MissingResourceContent", ...
            "Specify resource content with one of these fields: %s", ...
                    strjoin(contentFields,', '));
            end
        elseif ~isempty(x)
            error("prodserver:mcp:MissingResourceField", ...
           'Resource structure must contain the required fields: %s', ...
                strjoin(requiredFields, ', '));
        end
    else
        error("prodserver:mcp:InvalidResourceType", ...
            'Resource specification must be a structure, not a %s.', ...
            class(x));
    end
end