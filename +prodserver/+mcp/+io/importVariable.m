function value = importVariable(uri, type, config, opts)
%importVariable Fetch data from the URI and convert to a MATLAB variable
%using information in config. Imports variables from files, bytestreams
%or Kafka topics (with scheme file://, bytestream:// or kafka://).

% Copyright (c) 2025, The MathWorks

    arguments
        uri { prodserver.mcp.validation.mustBeURI }
        type string
        config struct
        opts.data struct = []
        opts.import { prodserver.mcp.validation.mustBeImportOptions} = []
    end

    import prodserver.mcp.internal.hasField
    import prodserver.mcp.io.parseURI
    import prodserver.mcp.internal.Constants

    if isstruct(uri)
        u = uri;
    else
        uri = string(uri);  % Escape from char data type
        u = parseURI(uri);
    end

    if nargin > 1
        config = prodserver.mcp.io.findConfig(config,u,type);
    end

    switch u.scheme
        case "literal"
            % The literal value is the query field -- see if we can do
            % better than just string.
            value = str2double(u.query);
            if isnan(value) && strcmpi(u.query,"nan") == false
                % Did not convert to a double. For now, it's a string.
                value = u.query;
            end
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

            inKS = kafkaStream(u.host, u.port, u.path, args{:});
            value = readtimetable(inKS);

        case "file"
            if nargin < 2
                error("prodserver:mcp:SchemeMissingConfig", ...
                    "Scheme %s requires configuration data.", ...
                    u.scheme);
            end

            % Convert File scheme URI to filesystem path. Only the File
            % scheme could know how to do this.
            pth = prodserver.mcp.io.uri.File.FileURI2Path(u);

            if exist(pth,"file") ~= 2
                error("prodserver:mcp:InaccessibleDataSource", ...
                    "Unable to locate or access data source %s.", pth);
            end

            % If there are multiple configurations available, use the one
            % matching the file extension.
            switch config.via
                case "load"

                    % Create a MATFILE object so that we don't have to load
                    % unnecessary data.
                    v = matfile(pth);

                    % What variable to load? That's an interesting
                    % question. If the framework saved the variable, the
                    % name will be the value of Constants.DefaultPersistVar. 
                    % Or the user might have set the variable name in the
                    % input configuration. Or, and this is the most
                    % challenging, the user might have just saved some
                    % arbitrary data with an arbitrary name.
                    fNames = string(who(v));
                    if isempty(fNames) || all(strlength(fNames) == 0)
                        % Well, that's disappointing.
                        error("prodserver:mcp:EmptyDataSource", ...
               "Data source %s contains no data or variables.", pth);
                    end
                    if hasField(config,"variable")
                        name = config.variable;
                    else
                        name = Constants.DefaultPersistVar;
                    end
                    % If the framework-based variable name is present, use
                    % that, otherwise there must be only one variable name,
                    % which we'll use.
                    if matches(name,fNames)
                        value = v.(name);
                    elseif isscalar(fNames)
                        value = v.(fNames);
                    else
                        error("prodserver:mcp:AmbiguousImport", ...
   "Data source %s contains multiple variables which do not match any " + ...
   "defaults. Specify name in configuration or a data source with only " + ...
   "one variable.", pth);
                    end

                case "readmatrix"
                    args = {};
                    if isempty(opts.import) == false
                        args = {opts.import};
                    end
                    value = readmatrix(pth, args{:});

                case "readtable"
                    args = {};
                    if isempty(opts.import) == false
                        args = {opts.import};
                    end
                    value = readtable(pth, args{:});
            end

        case "bytestream"
            value = getArrayFromByteStream(opts.data.(u.path));
        otherwise
            value = [];
    end

    
end
