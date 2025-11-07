classdef MarshallURI
%MarshallURI Manage scheme marshalling configuration.

% Copyright (c) 2024, The MathWorks, Inc.

    properties (SetAccess = private)
        config     % Map: scheme name -> scheme marshalling object
        sessionId  % Unique session identification string
    end

    properties (Access = private)
        schemePreset    % Default scheme
    end

    properties (Dependent)
        defaultScheme
        schemes
        session
    end

    properties(Constant,Hidden)
        % Match a variable name in a URI.
        varPattern = lookBehindBoundary("/") + wildcardPattern(Except="/") + ...
            lineBoundary("end");
    end

    methods(Static)

        function [config,scheme] = ImportConfiguration(file)
        %ImportConfiguration 
            import prodserver.mcp.internal.yaml2json
            import prodserver.mcp.internal.hasField
            
            import prodserver.mcp.io.Scheme

            try
                json = yaml2json(file);
                cfg = jsondecode(json);
            catch ex
                error("prodserver:mcp:BadMarshallConfigFile", ...
                     "Could not import URI marshalling configuration " + ...
                      "from file %s. Reason: %s", file,ex.message);
            end

            % The fields under "marshalling" are scheme marshalling
            % configurations. Create the config map.
            if hasField(cfg,"marshalling") && ~isempty(cfg.marshalling)
                config = configStruct2Dictionary(cfg.marshalling);
            else
                error("prodserver:mcp:BadMarshallConfigFile", ...
                     "Could not import URI marshalling configuration " + ...
                      "from file %s. Reason: %s", file,...
                           "Missing or empty 'marshalling' section.");
            end
            
            if hasField(cfg,"defaults.scheme")
                scheme = cfg.defaults.scheme;
            else
                scheme = string.empty;
            end
        end

        function ExportConfiguration(cfg,file,scheme)
        % Export the configuration templates and the tokens used to
        % instantiate them.
            import prodserver.mcp.internal.struct2yaml
            import prodserver.mcp.io.Scheme

            if nargin == 2 || isempty(scheme) || (isstring(scheme) && strlength(scheme) == 0)
                scheme = """""";  % Empty double-quotes
            end
            header = sprintf("schema:\n  type: ""marshalling""\n" + ...
              "  version: 0.9\ndefaults:\n  scheme: %s\nmarshalling:", ...
              scheme);
            writelines(header,file);
            schemes = keys(cfg);
            for n = 1:numel(schemes)
                sCfg = struct2yaml(cfg{schemes(n)}.template,4);
                sCfg = "  " + schemes(n) + ": " + sCfg;
                writelines(sCfg,file,WriteMode="append");
            end
        end
    end

    methods
        function mu = MarshallURI(opts)
            arguments
                % Configuration data is a structure or JSON string
                opts.Config = []
                % SessionID is a unique string
                opts.SessionID string = string.empty
            end
            import prodserver.mcp.io.Scheme

            args = {};
            if strlength(opts.SessionID) > 0  % Will never be isempty()
                mu.sessionId = opts.SessionID;
                args = { Scheme.sessionIdToken,mu.sessionId };
            end
            % Must always initialize to reset persistent tokens (which are
            % a performance optimization).
            Scheme.InitializeTokens(args{:});
            
            args = {};
            if ~isempty(opts.Config)
                args = { opts.Config };
            end
            mu = configure(mu,args{:});
        end

        function sid = get.session(mu)
        %get.session Unique identifier of current session.
            sid = mu.sessionId;
        end

        function names = get.schemes(mu)
        %get.schemes Names of all the known schemes.
            names = string(keys(mu.config));
        end

        function scheme = get.defaultScheme(mu)
        %get.defaultScheme Name of the default scheme.
            scheme = mu.schemePreset;
        end

        function mu = set.session(mu,id)
            import prodserver.mcp.io.Scheme

            mu.sessionId = id;
            Scheme.ModifyTokens(Scheme.sessionIdToken,mu.sessionId);
            mu = configure(mu);
        end

        function mu = set.defaultScheme(mu,scheme)
        %set.scheme Choose one of the existing schemes to be the default.
            
            import prodserver.mcp.internal.Constants

            name = extractBefore(scheme,Constants.SchemeSuffix); 
            if isKey(mu.config,name)
                mu.schemePreset = name;
            else
                error("prodserver:mcp:BadDefaultScheme", ...
     "Unrecognized scheme %s. Choose default scheme from set of " + ...
     "configured schemes: see 'schemes' property for a complete list.", ...
                    scheme);
            end
        end

        function tf = conforms(mu,uri)
        %conforms Does the URI conform to the rules for its scheme?
            import prodserver.mcp.internal.Constants
               

            if isempty(uri)
                tf = false;
                return;
            end

            tf = false(size(uri));
            isURI = startsWith(uri,Constants.SchemePattern);
            u = uri(isURI);
            stf = false(size(u));
            for n = 1:numel(u)
                scheme = extract(u(n),Constants.SchemeNamePattern);
                if isKey(mu.config,scheme)
                    stf(n) = conforms(mu.config{scheme},u(n));
                else
                    error("prodserver:mcp:UnknownScheme", ...
                        "Unrecognized scheme %s in data URI %s.",...
                        scheme, u(n));
                end
            end
            tf(isURI) = stf;
        end

        function tf = exist(mu,uri)
        %exist Does the URI exist in its scheme?
            import prodserver.mcp.internal.Constants
            

            if isempty(uri)
                tf = false;
                return;
            end

            tf = false(size(uri));
            isURI = startsWith(uri,Constants.SchemePattern);
            u = uri(isURI);
            stf = false(size(u));
            for n = 1:numel(u)
                scheme = extract(u(n),Constants.SchemeNamePattern);
                if isKey(mu.config,scheme)
                    stf(n) = exist(mu.config{scheme},u(n));
                else
                    error("prodserver:mcp:UnknownScheme", ...
                        "Unrecognized scheme %s in data URI %s.",...
                        scheme, u(n));
                end
            end
            tf(isURI) = stf;
        end

        function value = deserialize(mu,location,opts)
        %deserialize Retrieve a value from a scheme-based location.
        %
        %   VALUE = DESERIALIZE(MU,LOCATION) reads the data VALUE from
        %   LOCATION according to LOCATION's scheme. LOCATION is a string
        %   array. VALUE will be a cell array, even if LOCATION is scalar.     
        %
        %See also: serialize, reader, uri

            arguments
                mu prodserver.mcp.io.MarshallURI
                location
                opts.type = "double";
            end

            import prodserver.mcp.validation.istext
            if istext(location)
                location = prodserver.mcp.io.parseURI( ...
                    location);
            end
            readFcn = reader(mu,location,opts.type);
            value = cell(size(location));
            for n = 1:numel(location)
                value{n} = feval(readFcn{n},location(n));
            end
        end

        function update = serialize(mu,location,value)
        %serialize Place a value in a scheme-based location.
        %
        %   SERIALIZE(MU,LOCATION,VALUE) writes the data VALUE into
        %   LOCATION according to LOCATION's scheme. LOCATION is a string
        %   array. VALUE must be a cell array, even if LOCATION is scalar.  
        %
        %See also: deserialize, writer, uri

            import prodserver.mcp.validation.istext
            if istext(location)
                update = location;
                location = prodserver.mcp.io.parseURI( ...
                    location);
            end
            writeFcn = writer(mu,location);
            for n = 1:numel(location)
                if persist(mu,location(n),"query")
                    update(n) = feval(writeFcn{n},location(n),value{n});
                else
                    feval(writeFcn{n},location(n),value{n});
                end
            end
        end

        function rrloc = rerootURI(mu,loc,root)
        %rerootURI Change the root portion of the URI -- the part between
        %the scheme and the session ID.

            import prodserver.mcp.internal.Constants

            scheme = extractBefore(loc,Constants.SchemeSuffix);
            rrloc = strings(1,numel(scheme));
            for s = 1:numel(scheme)
                % Scheme controls URI format -- send each reformatting
                % request to the appropriate scheme.
                rrloc(s) = rerootURI(mu.config{scheme(s)},loc,root);
            end
        end

        function tf = isURI(mu,location)
        %isURI Is the URI valid according to the rules of its scheme?
            tf = false(size(location));
            for n = 1:numel(location)
                scheme = extract(location,Constants.SchemePattern);  
                if isKey(mu.config,scheme)
                    tf(n) = isURI(mu.config{scheme},location);
                else
                    error("prodserver:mcp:UnknownScheme", ...
                        "Unrecognized scheme %s in data URI %s.",...
                        scheme, location(n));
                end
            end
        end

        function u = uri(mu,varargin)
        %URI Return the URI of the variable. 
        %
        %   U = URI(MU, VAR, SCHEME, VALUE) return the URI of VARIABLE, 
        %   applying the default rules for the URIs of SCHEME. Some schemes
        %   require VALUE, some do not -- specifically, SCHEMEs with
        %   persist: query require VALUE, all others do not.
        %
        %   U = URI(MU, T) construct the URIs of the variables enumerated
        %   in table T, which must contain columns Name, URI and Value.
        %
        %See also: reader, writer

            import prodserver.mcp.internal.Constants
            

            narginchk(2,4);

            val = {};
            % True for nargin == [3,4]
            if nargin > 2
                var = varargin{1};
                scheme = varargin{2};
            end
            if nargin == 3
                % No value provided
                hasValue = false(size(var));

            elseif nargin == 4
                % Caller provided value
                hasValue = true(size(var));

                % Don't make caller wrap one value in an extra cell-array.
                % Wrap it ourselves, for uniform processing.
                if isscalar(var)
                    value = varargin(3);
                else
                    value = varargin{3};
                end
                val = value;

            elseif nargin == 2
                if istable(varargin{1})
                    t = varargin{1};
                    var = t.Name;
                    val = t.Value;
                    hasValue = t.HasValue;
                    scheme = extract(t.URI,Constants.SchemePattern);
                else
                    var = varargin{1};
                    hasValue = false(size(var));
                    scheme = extract(var,Constants.SchemePattern);
                    if isempty(scheme)
                        error("prodserver:mcp:SchemePrefixMissing", ...
                              "Scheme missing from URI %s.", var(1));
                    end
                end
            end
            
            if endsWith(scheme,Constants.SchemeSuffix)
                scheme = extractBefore(scheme,Constants.SchemeSuffix);
            end

            % Space for each URI.
            u = strings(numel(var),1);
            for n = 1:numel(var)
                % Delegate URI creation to scheme subclass.
                s = mu.config{scheme(n)}; 
                args{1} = var(n);
                if hasValue(n)
                    args(2) = val(n);
                end
                u(n) = defaultURI(s,args{:});
            end
        end

        function manifest(mu,file)
        %manifest Write configuration to file.
        %
        %See also: structure, configure

            import prodserver.mcp.io.MarshallURI
            MarshallURI.ExportConfiguration(mu.config,file,mu.schemePreset);
        end

        function tf = isactive(mu,scheme)
        %isactive Have the given schemes been activated?
            tf = size(scheme);
            scheme = keys(mu.config);
            for n = 1:numel(scheme)
                tf(n) = isactive(mu.config{scheme(n)});
            end    
        end

        function mu = activate(mu)
        %activate Allow scheme to accept storage requests for the current 
        %session.
            scheme = keys(mu.config);
            for n = 1:numel(scheme)
                mu.config{scheme(n)} = activate(mu.config{scheme(n)});
            end
        end

        function mu = deactivate(mu)
        %deactivate Block scheme from accepting any further storage requests.
            scheme = keys(mu.config);
            for n = 1:numel(scheme)
                mu.config{scheme(n)} = deactivate(mu.config{scheme(n)});
            end
        end

        function mu = configure(mu,cfg)
        %configure Initialize configuration from file or structure.
        %
        %See also: structure, manifest

            import prodserver.mcp.io.MarshallURI
            import prodserver.mcp.internal.hasField
            if nargin > 1
                if isstruct(cfg)
                    if hasField(cfg,"marshalling")
                        mu.config = configStruct2Dictionary(cfg.marshalling);
                    end
                    if hasField(cfg,"defaults.scheme")
                        mu.schemePreset = cfg.defaults.scheme;
                    end
                else
                    [mu.config,mw.scheme] = MarshallURI.ImportConfiguration(cfg);
                end
            else
                mu.config = assembleConfiguration();
            end
        end

        function s = structure(mu)
        %structure Marshalling configuration as a structure.
        %
        %See also: manifest, configure

            names = keys(mu.config);
            for n = 1:numel(names)
                s.(names(n)) = mu.config{names(n)}.configuration;
            end
        end

        function tf = persist(mu,uri,type)
        %persist Does uri have persistence type?
            import prodserver.mcp.validation.istext
            import prodserver.mcp.io.parseURI
            
            import prodserver.mcp.internal.hasField

            if istext(uri)
                uri = parseURI(uri);
            end

            tf = false(size(uri));
            for n = 1:numel(uri)
                if isKey(mu.config, uri(n).scheme)
                    md = mu.config{uri(n).scheme}.configuration;
                    if hasField(md,"defaults.persist")
                        tf(n) = strcmpi(md.defaults.persist,type);
                    else
                        error("prodserver:mcp:SchemeFieldMissing", ...
                     "Field %s missing from definition of scheme %s.", ...
                            "defaults.persist", uri(n).scheme);
                    end
                else
                    error("prodserver:mcp:UnknownScheme", ...
                        "Unrecognized scheme %s in data URI %s.",...
                        uri(n).scheme, uri(n).uri);  
                end
            end
        end

        function tf = accomodate(mu, uri)
        %accomodate Notify storage manager to allow uri to be written.
            tf = false(size(uri));
            for n = 1:numel(uri)
                % Remove the variable name from the URI path.
                pth = uri(n).path;
                var = extract(pth,mu.varPattern);
                % Recreate the URI without the variable name.
                uri(n).path = erase(pth,var + lineBoundary("end"));
                uri(n).uri = prodserver.mcp.io.assembleURI(uri(n));
                tf(n) = create(mu,uri(n));
            end
        end

        function writeFcn = writer(mu,uri,variable)
        %writer Return a function that serializes values into the format of
        %the scheme in the given URI.

            
            import prodserver.mcp.internal.hasField

            writeFcn = cell(1,numel(uri));
            for n = 1:numel(uri)
                if isKey(mu.config, uri(n).scheme)
                    md = mu.config{uri(n).scheme}.configuration;
                    if nargin > 2
                        % Save using specified variable name, if format
                        % permits it.
                        md.write.variable = variable(n);
                    end
                    if hasField(md,"write.fcn")
                        writeFcn{n} = @(var,val)feval(md.write.fcn,var,val, ...
                            md.write);
                    else
                        error("prodserver:mcp:SchemeFieldMissing", ...
                            "Field %s missing from definition of scheme %s.", ...
                            "write.fcn", uri(n).scheme);
                    end
                else
                    error("prodserver:mcp:UnknownScheme", ...
                        "Unrecognized scheme %s in data URI %s.",...
                        uri(n).scheme, uri(n));  
                end
            end
        end

        function readFcn = reader(mu,uri,type)
        %reader Return a function that deserializes values formatted
        %according to the scheme of the given URI.
        %
        %See also: writer, accomodate

            
            import prodserver.mcp.internal.hasField

            readFcn = cell(1,numel(uri));
            for n = 1:numel(uri)
                if isKey(mu.config, uri(n).scheme)
                    md = mu.config{uri(n).scheme}.configuration;
                    if hasField(md,"read.fcn")
                        readFcn{n} = @(var)feval(md.read.fcn,var,type,md.read);
                    else
                        error("prodserver:mcp:SchemeReadMissing", ...
              "Field 'read.fcn' missing from definition of scheme %s.", ...
                            uri(n).scheme);
                    end
                else
                    error("prodserver:mcp:UnknownScheme", ...
                        "Unrecognized scheme %s in data URI %s.",...
                        uri(n).scheme, uri(n));
                end
            end
        end
    end

    methods (Access=private)

        function mgr = persistMgr(mu,uri)
        %persistMgr Full path to the persistence manager for uri.
            import prodserver.mcp.internal.hasField

            if isKey(mu.config, uri.scheme)
                cfg = mu.config{uri.scheme}.configuration;
            else
                error("prodserver:mcp:UnknownScheme", ...
                    "Unrecognized scheme %s in data URI %s.",...
                    uri.scheme, uri.uri);  
            end

            if ~hasField(cfg,"defaults.manager")
                error("prodserver:mcp:ManagerUndefined", ...
              "Scheme for %s must define a persistence manager.", ...
                      uri.scheme);
            end
            ext = "";
            if ispc, ext = ".exe"; end
            mgr = cfg.defaults.manager;
            if strlength(mgr) == 0
                mgr = string.empty;
                return;
            end
            mgr = sprintf("%s%s",mgr,ext);
            if isdeployed
                % Search the deployed archive for the persistence
                % manager.
                if ispc
                    exePattern = ext + lineBoundary("end");
                    if contains(mgr,exePattern) == false
                        mgr = mgr + ext;
                    end
                end
                w = which(mgr);
                if ~isempty(w)
                    mgr = w;
                end
            end
            % Convert slashes to filesystem native orientation
            mgr = fullfile(mgr);
            if isfile(mgr) == false
                error("prodserver:mcp:ManagerAWOL",...
           "Could not locate persistence manager for %s at %s.", ...
                    scheme, mgr);
            end
        end

        function results = persistCmd(mu,cmd,uri,varargin)
            
            mgr = persistMgr(mu,uri);
            if isempty(mgr)
                results = uri.uri;
            else
                optional = strjoin(string(varargin), " ");
                pCmd = sprintf("""%s"" %s ""%s"" %s", mgr, cmd, uri.uri, optional);
                [status,results] = system(pCmd);
                if status ~= 0
                    error("prodserver:mcp:PersistCommandFailed", ...
             "Persistence command failed.\nCommand: %s\nFailure: %s", ...
                        pCmd, results);
                end
            end
        end

       function tf = create(mu,variable)
       %create Create a variable or location.
            results = persistCmd(mu,"create",variable);
            if strlength(results) == 0
                tf = true(1,numel(variable));
            else
                tf = false(1,numel(variable));
            end
       end
    end
end

function config = assembleConfiguration()
%assembleConfiguration Create the configuration data by querying
%each subclass of Scheme for its scheme-specific configuration.
    import prodserver.mcp.io.Scheme
    import prodserver.mcp.internal.redAlert
    
    clsNames = Scheme.SchemeClasses();
    config = configureDictionary("string","cell");
    for cls = clsNames
        try
            % Invoke constructor
            cfg = feval(cls);
        catch ex
            redAlert("SchemeCtorFailed", ...
                "Failed to create Scheme %s: %s", cls, ex.message);
        end
        % Attach configuration to class name in Scheme dictionary.
        config{Scheme.Name(cls)} = cfg;
    end
end

function config = configStruct2Dictionary(cfg)
% The returned dictionary maps short scheme names to Scheme subclasses.
% Each subclass is initialized with the scheme-specific configuration data
% in cfg.
    schemes = string(fieldnames(cfg));
    config = configureDictionary("string","cell");
    for n = 1:numel(schemes)
        cls = cfg.(schemes(n)).defaults.class;
        config{schemes(n)} = feval(cls,cfg.(schemes(n)));
    end
end