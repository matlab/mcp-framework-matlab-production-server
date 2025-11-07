classdef Redis < prodserver.mcp.io.Scheme
%Redis Marshalling configuration for the redis:// scheme.
%
%Minimal class required by scheme extension framework.

% Scheme-related errors belong in the storage category: storage.xml in the
% resources/data_pipeline/en folder.

% Copyright (c) 2024, The MathWorks, Inc.

    methods
        function fs = Redis(varargin)
            fs = configure(fs, fileparts(mfilename("fullpath")), ...
                varargin{:});
        end

        function tf = isactive(~)
        %isactive Has the Redis scheme been activated? (False until 
        %implemented).
            tf = true;
        end

        function s = activate(s)
        %activate Begin accepting storage requests. Connect to storage cache.
            import prodserver.mcp.internal.redAlert
        end

        function s = deactivate(s)
        %deactivate Stop accepting storage requests. Disconnect from cache.
            import prodserver.mcp.internal.redAlert
        end

        function s = clear(s)
        %clear Remove all persistent data, but leave cache in place.
            import prodserver.mcp.internal.redAlert
        end

        function tf = exist(~,uri)
        %exist Does the URI exist in the scheme?
            import prodserver.mcp.internal.redAlert
            tf = false(size(uri));
            redAlert("NotYetImplemented");
        end
    end
end