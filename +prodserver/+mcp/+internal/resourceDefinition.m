function resource = resourceDefinition(resourceList)
% resourceList is a call array of resource structures with varying fields.
%
% Create a resource structure from the list of resources. The structure
% has these fields:
%
%   uri         : The server-unique path to the resource. RFC 3986.
%   name        : Machine-readable name of the resource.
%   title       : Title used for display.
%   description : Human readable description of the contents.
%   mimeType    : MIME format of the contents.
%   contents    : The resource contents, the data, etc.
%   reference   : A URI pointing to the resource data
%   import      : An ImportOptions used to import the resource from its
%                 location.
%   
% Only uri and contents must have values. The others may be 
% empty. But the system works better if they aren't.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.internal.Constants
    import prodserver.mcp.internal.hasField

    resource = resourceList;
    if isstruct(resource)
        resource = num2cell(resourceList);
    end

    % Build a MarshallURI object to import data from files and references.
    m = prodserver.mcp.io.MarshallURI;

    % Set defaults and capture the contents of file-based resources.
    for n = 1:numel(resource)

        % An empty mimeType is no mimeType: text gets the default, rather
        % than being taken for binary and served Base64 encoded.
        resource{n} = withoutEmptyMIMEType(resource{n});
        [resource{n},name] = fetchIndirectContents(resource{n},m);
        resource{n} = withoutEmptyMIMEType(resource{n});

        % Text and raw bytes get a default mimeType: resources/read needs
        % one to tell text from a blob.
        if hasField(resource{n},"mimeType") == false
            if prodserver.mcp.validation.istext(resource{n}.contents)
                resource{n}.mimeType = Constants.MIMETypePlainText;
            elseif isa(resource{n}.contents,"uint8")
                resource{n}.mimeType = Constants.MIMETypeBinary;
            end
        end

        % If no name field, form name from file name, or use "resourceN"
        if hasField(resource{n},"name") == false
            if strlength(name) > 0
                resource{n}.name = name;
            else
                resource{n}.name = sprintf("resource%d",n);
            end
        end    

        % No useful default for description. Or title.
    end
end
    

function [resource,name] = fetchIndirectContents(resource,marshaller)
% Fetch resource contents from a location:
%
%   * If the resource is a function handle, replace resource.contents with
%     the result of calling the function.
%   * If the resource is specified as a file, replace the resource.contents with
%     the contents of the file.
%   * If there's a reference field, fetch the data at the reference using
%     the marshaller.

    import prodserver.mcp.internal.Constants
    import prodserver.mcp.internal.hasField

    % Suggested name for the resource -- based lightly on location.
    name = "";

    if isa(resource.contents,"function_handle")
        % If the contents is a function handle, call the function -- the
        % result is the resource. Its name comes from the function, which
        % the result no longer holds.
        fcn = resource.contents;
        resource = feval(fcn);
        if isvarname(func2str(fcn))
            name = func2str(fcn);
        end
    elseif hasField(resource,"reference")
        prodserver.mcp.validation.mustBeURI(resource.reference);
        resource = deserialize(marshaller,resource.reference);
    elseif ischar(resource.contents) || ...
            (isstring(resource.contents) && isscalar(resource.contents))
        if matches(resource.contents,Constants.PathPattern) && ...
                exist(resource.contents,"file") == 2
            % If the contents is a file path, replace the path with the
            % contents of the file.
            [~,name,ext] = fileparts(resource.contents);
            if strlength(ext) > 0
                ext = extractAfter(ext,"."); 
                name = name + string(ext);
            end

            resource = fileContents(resource,marshaller);
        end
    end
end

function resource = fileContents(resource,marshaller)
% Get the contents of a file-based resource. Binary files are read as a
% uint8 row vector. Text and binary are told apart by the same rule the
% resources/read handler uses, so application/json and friends are text.
    import prodserver.mcp.internal.Constants
    import prodserver.mcp.internal.hasField

    if hasField(resource,"import")     
        loc = prodserver.mcp.io.uri.File.Path2FileURI(resource.contents);
        resource.contents = deserialize(marshaller,loc,import=resource.import);
    elseif hasField(resource,"mimeType") && ...
            ~prodserver.mcp.jsonrpc.isMIMETypeText(resource.mimeType)
        % Not a text file.
        fp = fopen(resource.contents,"r");
        closeFile = onCleanup(@() fclose(fp));
        resource.contents = fread(fp,"*uint8")';
    else
        resource.contents = prodserver.mcp.internal.readUTF8(...
            resource.contents);
        if ~hasField(resource,"mimeType")
            resource.mimeType = Constants.MIMETypePlainText;
        end
    end

end

function resource = withoutEmptyMIMEType(resource)
% Remove an empty mimeType field, so that it is treated as missing.
    if isstruct(resource) && isfield(resource,"mimeType") && ...
            prodserver.mcp.validation.istext(resource.mimeType) && ...
            all(strlength(resource.mimeType) == 0)
        resource = rmfield(resource,"mimeType");
    end
end
