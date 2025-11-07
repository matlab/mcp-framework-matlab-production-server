classdef Literal < prodserver.mcp.io.Scheme
%Literal Marshalling configuration for the literal:// scheme.
%
%Minimal class required by scheme extension framework.

% Scheme-related errors belong in the storage category: storage.xml in the
% resources/data_pipeline/en folder.

% Copyright (c) 2024, The MathWorks, Inc.

    methods
        function fs = Literal(varargin)
            fs = configure(fs, fileparts(mfilename("fullpath")), ...
                varargin{:});
        end

        function tf = isactive(~)
        %isactive Has the Literal scheme been activated? (Always true).
            tf = true;
        end

        function s = activate(s)
        %activate Begin accepting storage requests. No-op for Literal.
        end

        function s = deactivate(s)
        %deactivate Stop accepting storage requests. No-op for Literal.
        end

        function s = clear(s)
        %clear Remove all persistent data, but leave container in 
        %place. No-op for Literal!
        end

        function tf = exist(~,uri)
        %exist Does the URI exist in the scheme?
            import prodserver.mcp.internal.redAlert
            tf = false(size(uri));
            redAlert("NotYetImplemented");
        end
    end
end