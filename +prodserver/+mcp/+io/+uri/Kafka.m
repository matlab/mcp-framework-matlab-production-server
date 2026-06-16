classdef Kafka < prodserver.mcp.io.Scheme
%Kafka Marshalling configuration for the kafka:// scheme.
%
%Minimal class required by scheme extension framework.

% Scheme-related errors belong in the storage category: storage.xml in the
% resources/data_pipeline/en folder.

% Copyright (c) 2024, The MathWorks, Inc.

    methods
        function fs = Kafka(varargin)
            fs = configure(fs, fileparts(mfilename("fullpath")), ...
                varargin{:});
        end

        function tf = isactive(~)
        %isactive Has the Kafka scheme been activated? (Always false, 
        %until implemented).
            tf = false;
        end

        function s = activate(s)
        %activate Begin accepting storage requests. Connect to Kafka topic.
            import prodserver.mcp.internal.redAlert
        end

        function s = deactivate(s)
        %deactivate Stop accepting storage requests. Disconnect from Kafka topic.
            import prodserver.mcp.internal.redAlert
        end

        function clear(s)
        %clear Remove all persistent data, but leave container in place.
        %No-op for Kafka, because topics are immutable.
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