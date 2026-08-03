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
%   
% Only uri and contents must have values. The others may be 
% empty. But the system works better if they aren't.

% Copyright 2026-2026 The MathWorks, Inc.

    import prodserver.mcp.internal.Constants
    import prodserver.mcp.internal.hasField

    resource = resourceList;
    if isstruct(resource)
        resource = num2cell(resourceList);
    end

    % Set defaults and capture the contents of file-based resources.
    for n = 1:numel(resource)

        [resource{n},file] = fetchIndirectContents(resource{n});

        if hasField(resource{n},"mimeType") == false && ...
                prodserver.mcp.validation.istext(resource{n}.contents)
            resource{n}.mimeType = Constants.MIMETypePlainText;
        end

        % If no name field, form name from file name, or use "resourceN"
        if hasField(resource{n},"name") == false
            if strlength(file) > 0
                [~,name,ext] = fileparts(file);
                resource{n}.name = name;
                if strlength(ext) > 0
                    ext = extractAfter(ext,"."); 
                    resource{n}.name = resource{n}.name + string(ext);
                end
            else
                resource{n}.name = sprintf("resource%d",n);
            end
        end    

        % No useful default for description. Or title.
    end
end
    

function [resource,file] = fetchIndirectContents(resource)
% If the resource is specified as a file, replace the resource.contents with
% the contents of the file.
    import prodserver.mcp.internal.Constants

    % Not until proven to be a file.
    file = "";

    % If the contents is a file path, replace the path with the
    % contents of the file.
    if ischar(resource.contents) || ...
            (isstring(resource.contents) && isscalar(resource.contents))
        if matches(resource.contents,Constants.PathPattern) && ...
                exist(resource.contents,"file") == 2
            file = resource.contents;
            resource = fileContents(resource);
        end
    end
end

function resource = fileContents(resource)
% Get the contents of a file-based resource. Binary files are read as an
% array of uint8 bytes.
    import prodserver.mcp.internal.Constants
    import prodserver.mcp.internal.hasField

    if hasField(resource,"mimeType") 
        if startsWith(resource.mimeType,"text")
            resource.contents = fileread(resource.contents);
        else
            fp = fopen(resource.contents,"r");
            resource.contents = uint8(fread(fp));
        end
    else
        resource.contents = fileread(resource.contents);
        resource.mimeType = Constants.MIMETypePlainText;
    end

end