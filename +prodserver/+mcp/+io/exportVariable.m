function data = exportVariable(uri, value, config)
%exportVariable Convert the MATLAB value to data, as determined by the
%schema, and send it to the uri, using information in config. Exports
%values to files, Kafka streams or bytestreams (with scheme file://, 
% kafka:// or bytestream://).

% Copyright (C) 2022-2025, The MathWorks

    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.Constants
    import prodserver.mcp.io.parseURI

    if isstruct(uri)
        u = uri;
    else
        uri = string(uri);  % Escape from char data type
        u = parseURI(uri);
    end
    if nargin > 2
        config = prodserver.mcp.io.findConfig(config,u, ...
            class(value));
    end

    data = [];
    switch u.scheme
        case "literal"
            data = value;

        case "kafka"
            if nargin < 2
                error("prodserver:mcp:SchemeMissingConfig", ...
                    "Scheme %s requires configuration data.", ...
                    u.scheme);
            end
            % Requires Streaming Data Framework for MATLAB Production
            % Server (a support package).
            w = which("kafkaStream");
            if isempty(w)
                error("prodserver:mcp:InstallStreamFramework", ...
                    "Could not find function 'kafkaStream'. " + ...
                    "Please install Streaming Data Framework for MATLAB " + ...
                    "Production Server");
            end
            args = {};
            if hasField(config,"rows")
                args = [ { "Rows="+config.rows } args ];
            end

            outKS = kafkaStream(u.host, u.port, u.path, args{:});
            writetimetable(outKS,value);

        case "file"
            if nargin < 2
                 error("prodserver:mcp:SchemeMissingConfig", ...
                    "Scheme %s requires configuration data.", ...
                    u.scheme);
            end
            % Convert File URI path to file system path, which only File
            % scheme can be reasonably expected to know how to do.
            pth = prodserver.mcp.io.uri.File.FileURI2Path(u);
            switch config.via
                case "save"
                    if hasField(config,"variable")
                        name = config.variable;
                    else
                        name = Constants.DefaultPersistVar;
                    end

                    % Save into a structure with a known field name, so
                    % that load can retrieve it.
                    v.(name) = value;
                    args = {};
                    save(pth, "-struct", "v", args{:});

                case "writematrix"
                    args = {};
                    writematrix(value, pth, args{:});

                case "writetable"
                    args = {};
                    writetable(value, pth, args{:});
            end

        case "bytestream"
            data = getByteStreamFromArray(value);
    end

    
end
