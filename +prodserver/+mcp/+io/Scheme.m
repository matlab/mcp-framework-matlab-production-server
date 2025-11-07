classdef (Abstract) Scheme
%Scheme Superclass for all scheme marshalling configuration classes.
%
%To add a new scheme, define a new class in the <pipeline namespace>.io.uri
%namespace. The constructor of the new class must call Scheme.initialize
%with the location of a folder containing a <NewScheme>.yaml file. The YAML
%file defines the functions uses to import and export variables using the
%new scheme.
%
%See also: prodserver.mcp.io.uri.File

% Copyright 2024-2025 The MathWorks, Inc.

    properties (Constant,Hidden)
        namespace = schemeNamespace("Scheme");

        % Unique session identifier
        sessionIdToken = "$sessionID";

        % Scheme-specific full path to container of session data.
        sessionRootToken = "$sessionRoot";

        % Name of the pipeline.
        pipelineToken = "$pipeline";
    end

    methods (Static)

        function InitializeTokens(name,value)
        %InitializeTokens Fill the tokens dictionary with the defaults and
        %add any tokens given as inputs. Token names and values are always
        %strings.

            arguments
                name string = ""
                value string { mustBeSameSize(1,name,value) } = ""
            end

            import prodserver.mcp.validation.mustBeSameSize
            import prodserver.mcp.io.Scheme
            import prodserver.mcp.internal.redAlert
            
            % Tokens common to all schemes
            t = commonTokens();
            name = strtrim(name);
            if all(strlength(name)) > 0 
                % Tokens specific to this initialization
                t(name) = value;
            elseif ~isscalar(name)
                n = find(strlength(name) == 0,1,"first");
                redAlert("BadTokenName", "Token %d has length zero " + ...
                    "after whitespace trimming.", n);
            end
            % Remember token dictionary so all schemes share it.
            ConfigurationTokens(t);
        end

        function ModifyTokens(name, value)
        %ModifyTokens Update existing or add new tokens into 
        % ConfigurationTokens.
            t0 = ConfigurationTokens();
            t1 = dictionary(name,value);
            ConfigurationTokens(merge(t0,t1));
        end

        function tokens = Tokens()
            tokens = ConfigurationTokens();
        end
            
        function name = Name(cls)
            import prodserver.mcp.io.Scheme
            name = lower(extract(cls,Scheme.namePattern));
        end

        function mc = MarshallingConfiguration(varargin)
            mc = prodserver.mcp.io.MarshallURI(varargin{:});
        end
    end

    methods(Static)
        function cls = SchemeClasses(action)
        % Names of all the known subclasses of Scheme -- all the ones in
        % the expected namespace at least.

            import prodserver.mcp.io.Scheme
            import prodserver.mcp.internal.redAlert

            persistent clsList
            if nargin == 0
                action = "get";
            end
            if isempty(clsList) || strcmpi(action,"refresh")
                mc = matlab.metadata.Namespace.fromName(Scheme.namespace);
                if isempty(mc) || isempty(mc.ClassList)
                    redAlert("EmptyMarshallingNamespace", "Expecting " + ...
          "at least one Scheme subclass in namespace %s but found " + ...
                        "none.", Scheme.namespace);
                else
                    clsList = string({ mc.ClassList.Name });
                end
            end
            cls = clsList;
        end
    end

    properties (Access = protected)
        configTemplate   % Original configuration data
        tokenizedConfig  % Configuration after tokens applied
        tokens
    end

    properties(Dependent, SetAccess=immutable)
        configuration   % Configuration with tokens replaced by values.
        template        % Configuration before tokens replaced by values.
    end

    properties(Constant,Hidden)
        namePattern = wildcardPattern(Except=".")+textBoundary("end");
    end

    methods (Abstract)
        % Allow scheme to accept storage requests for a given session.
        s = activate(s,sid)
        % Block scheme from accepting any further storage requests. 
        s = deactivate(s)
        % Is the scheme active?
        tf = isactive(s)
        % Remove all persistent data, but leave container in place.
        s = clear(s)
        % Is there a value at the URI?
        tf = exist(s,uri);
    end

    methods

        function tf = conforms(s,uri,varargin)
        %conforms Does the URI conform to the scheme?
        % Must start with <scheme>: and be a URI. If the path may contain
        % non-standard characters without percent-encoding, list those
        % characters in pathChars. The File scheme, for example, allows :
        % in paths to support the Windows drive letter syntax.
        %
        % Subclasses are encouraged to override this function.

            if isempty(uri)
                tf = false;
            else
                
                tf = startsWith(uri,prefix(s)) && ...
                    prodserver.mcp.validation.isuri(uri, ...
                        varargin{:});
            end
        end

        function cfg = get.template(s)
            cfg = s.configTemplate;
        end

        function cfg = get.configuration(s)
            cfg = s.tokenizedConfig;
        end

        function scheme = prefix(s)
        %prefix Return <scheme>:, where <scheme> is the lowercase name of
        %the subclass of Scheme (guaranteed never to be Scheme itself,
        %since Scheme is Abstract and cannot be instantiated).
            import prodserver.mcp.internal.Constants
            scheme = split(class(s),".");
            scheme = lower(scheme(end)) + Constants.SchemeSuffix;
        end

        function u = applySessionId(s,uri)
        %applySessionId Apply (add?) a session root to the URI, the
        %intent of which is to make the URI unique in the Scheme's
        %namespace. Default implementation adds the session ID to the front
        %of the URI path. This may or may not be viable for all schemes, so
        %subclasses may override this method. (An alternative might be to
        %add the session ID as a query parameter to the URI.)
        %
        % This is typically more necessary for output variables than
        % inputs.
       
            import prodserver.mcp.internal.Constants
            id = s.tokens(s.sessionIdToken);
            u = prodserver.mcp.io.parseURI(uri);
            u.path = id + Constants.URISep + u.path;
            u = prodserver.mcp.io.assembleURI(u);
        end

        function u = rerootURI(s,uri,root)
        %rerootURI Change the root portion of the URI -- that part between
        %the scheme and the session ID.
        %
        %This is the default behaviour, of course, and concrete Schemes may
        %decide to take a different course.

            import prodserver.mcp.internal.Constants
            import prodserver.mcp.io.normalizeURI
            import prodserver.mcp.internal.parseSessionID

            sid = parseSessionID(s.tokens(s.sessionIdToken));
            between = extractBetween(uri,Constants.SchemePattern, ...
                sid+asManyOfPattern(wildcardPattern)+ textBoundary("end"));

            terminated = endsWith(root,Constants.URISep);
            if any(terminated) == false
                root(~terminated) = root(~terminated) + Constants.URISep;
            end
           
            % Convert root, which was passed in by client, into valid URI.
            root = prodserver.mcp.io.percentEncode(root);

            u = replace(uri,between,root);
            u = normalizeURI(u);
        end

        function u = defaultURI(s,var,val)
        %defaultURI Return the default URI under this scheme. Subclasses
        %may overload this method.
        %
        %   U = defaultURI(S,VAR,VAL) combines scheme-specific parameters
        %   with VAR and VAL to produce the default URI for scheme S. VAL
        %   may be specified if and only if scheme S defines persist:
        %   query.
        
            import prodserver.mcp.internal.Constants
            import prodserver.mcp.internal.hasField
            
            scheme = split(class(s),".");
            scheme = lower(scheme(end)) + Constants.SchemeSuffix;
            u = scheme + var;
            if nargin > 2
                if hasField(s.tokenizedConfig, "defaults.persist") == false || ...
                    strcmpi(s.tokenizedConfig.defaults.persist,"query") == false
                      error("prodserver:mcp:NotValueScheme",...
       "Unable to create URI for variable %s because scheme %s does " + ...
       "not store value in URI.", var,scheme);
                end
                try
                    if isnumeric(val)
                        % More significant digits than string()
                        vStr = jsonencode(val);
                    elseif ischar(val)
                        vStr = "'" + string(val) + "'";
                    else
                        vStr = string(val);
                    end
                    u = u + Constants.ParamStart + vStr;
                catch ex
                    error("prodserver:mcp:NotConvertibleToString",...
        "Unable to create URI for variable %s because value of type %s " + ...
        "is not convertible to string.",var,class(val));
                end
            end
        end
    end

    methods (Access = protected)

        function s = configure(s,folder,varargin)
            import prodserver.mcp.internal.yaml2json
            import prodserver.mcp.internal.normalizeConfig
            import prodserver.mcp.internal.DictionaryHandle
            % Import yourself to call your own static methods.
            import prodserver.mcp.io.Scheme

            name = extract(class(s), s.namePattern);
            s.tokens = DictionaryHandle("string","string");

            if nargin > 2
                % varargin may contain:
                % * A token-defining dictionary, the contents of which are
                %   added to the class-wide ConfigurationTokens dictionary.
                % * A structure, which must be the scheme-specific
                %   marshalling configuration template.
                % Either, both or neither of these may be present, in any
                % order. Argument type determines what action to take.

                for n = 1:numel(varargin)
                    a = varargin{n};
                    if isa(a,"dictionary") || isa(a,"DictionaryHandle")
                        % Add scheme-specific tokens to configuration 
                        % tokens dictionary.
                        merge(s.tokens, a);
                    elseif isstruct(a)
                        s.configTemplate = a;
                    end
                end
            end

            if isempty(s.configTemplate)
                % Read the configuration into a JSON string.
                json = yaml2json(fullfile(folder,name+".yaml"));
                s.configTemplate = normalizeConfig(jsondecode(json));
                % Inject class name into "defaults" section.
                s.configTemplate.defaults.class = class(s);
            end

            s.tokenizedConfig = Scheme.TokenizeConfiguration(s.tokens, ...
                s.configTemplate);
        end
    end

    methods (Static, Access = protected)

        function config = TokenizeConfiguration(tokens,config)

            import prodserver.mcp.internal.replaceTokens

             merge(tokens,ConfigurationTokens());

            % The configuration may contain one or more variable tokens
            % ($<name>). Replace these with the values in the token
            % dictionary.
            config = replaceTokens(tokens,config);
            
        end
    end
end

function namespace = schemeNamespace(cls)
% Use location of this file to determine namespace of schemes.
    namespace = extractAfter(mfilename("fullpath"),"+");
    namespace = extractBefore(namespace,cls);
    namespace = strrep(namespace,filesep,".");
    namespace = erase(namespace,"+");
    namespace = namespace + "uri";
end

function tokens = commonTokens()
% commonTokens Sets token values common to all Schemes
    import prodserver.mcp.internal.DictionaryHandle
    tokens = DictionaryHandle("string","string");
    tokens("$arch") = computer("arch");
    pkgRoot = fullfile(prodserver.mcp.internal.packageFolder);
    tokens("$packageRoot") = replace(pkgRoot,"\","/");
    if isdeployed
        [bin,ctf] = prodserver.mcp.internal.binFolder("persist");
        if isfolder(bin)
            toolsRoot = bin;
        elseif isfolder(ctf)
            toolsRoot = ctf;
        else
            error("data_pipeline:storage:NoToolsRoot", "Could not locate storage tools root folder:\n'%s'\n'%s'.", ...
                bin,ctf);
        end
    else
        toolsRoot = fullfile(prodserver.mcp.internal.binFolder("persist"));
    end
    tokens("$toolsRoot") = replace(toolsRoot,"\","/");
end

function tokens = ConfigurationTokens(tokens)
%ConfigurationTokens A handle object shared by all schemes associated with
%a given workspace. 
    import prodserver.mcp.internal.DictionaryHandle
    persistent t
    if nargin > 0
        t = tokens;
    elseif isempty(t) 
        t = DictionaryHandle("string","string");
    end
    tokens = t;
end