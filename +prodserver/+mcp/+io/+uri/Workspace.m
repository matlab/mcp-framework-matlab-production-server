classdef Workspace < prodserver.mcp.io.Scheme
%Workspace Marshalling configuration for the workspace:// scheme.
%
%Minimal class required by scheme extension framework.

% Scheme-related errors belong in the storage category: storage.xml in the
% resources/data_pipeline/en folder.

% Copyright (c) 2024, The MathWorks, Inc.

    methods
        function fs = Workspace(varargin)
            fs = configure(fs, fileparts(mfilename("fullpath")), ...
                varargin{:});
        end

        function tf = isactive(~)
        %isactive Has the Workspace scheme been activated? (Always true).
            tf = true;
        end

        function s = activate(s)
        %activate Begin accepting storage requests. No-op for Workspace.
        end

        function s = deactivate(s)
        %deactivate Stop accepting storage requests. No-op for Workspace.
        end

        function s = clear(s)
        %clear Remove all persistent data, but leave container in 
        %place. No-op for Workspace?
        end

        function tf = exist(~,uri)
        %exist Does the URI exist in the scheme?

            % The workspace scheme (by definition) does not use any kind of
            % external storage so URIs have no independent existence.
            tf = false(size(uri));

        end
    end
end