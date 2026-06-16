classdef JSON < prodserver.mcp.io.Scheme
%JSON Marshalling configuration for the json:// scheme.
%
%Minimal class required by scheme extension framework.

% Scheme-related errors belong in the storage category: storage.xml in the
% resources/data_pipeline/en folder.

% Copyright (c) 2024, The MathWorks, Inc.

    methods
        function fs = JSON(varargin)
            fs = configure(fs, fileparts(mfilename("fullpath")), ...
                varargin{:});
        end

        function u = defaultURI(f,var,value)
        %defaultURI Construct defaultURI for var under the json scheme.
        
            import prodserver.mcp.internal.Constants

            u = prefix(f) + var;
            if nargin > 2
                query = prodserver.mcp.io.toJSON(value);
                u = u + Constants.ParamStart + query;
            end
        end

        function tf = isactive(~)
        %isactive Has the JSON scheme been activated? (Always true).
            tf = true;
        end

        function s = activate(s)
        %activate Begin accepting storage requests. No-op for JSON.
            import prodserver.mcp.internal.redAlert
        end

        function s = deactivate(s)
        %deactivate Stop accepting storage requests. No-op for JSON.
            import prodserver.mcp.internal.redAlert
        end

        function s = clear(s)
        %clear Remove all persistent data, but leave container in 
        %place. No-op for JSON.
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


% Introduced from / by JSON.yaml. Called indirectly. MATLAB Compiler will
% never find them without this hint.

%#function prodserver.mcp.io.importJSON
%#function prodserver.mcp.io.exportJSON
