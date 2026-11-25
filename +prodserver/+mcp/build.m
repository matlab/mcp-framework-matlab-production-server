function [ctf,endpoint] = build(fcn, opts)
%build Create an MCP tool from fcn. Optionally deploy the tool to
%MATLAB Production Server.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        % Name of the function to be built into a tool.
        fcn string {prodserver.mcp.validation.mustNotBeReservedToolName(fcn, "function"), prodserver.mcp.validation.mustBeFunction}

        % Deploy tool to this server, if given.
        opts.server string { mustBeServerOrEmpty } = string.empty 

        % Base name of generated deployable archive.
        opts.archive string {prodserver.mcp.validation.mustBeArchiveName} = basename(fcn(1))

        % Name of MCP tool on server. May differ from FCN. But must always
        % be the same size as FCN. Not the name of one of the framework's
        % own tools (read_mcp_resource, uri2json); nor may FCN be one.
        opts.tool string {prodserver.mcp.validation.mustNotBeReservedToolName} = basename(fcn)

        % Folder in which to generate deployable archive and other files.
        opts.folder (1,1) string = "./deploy"

        % List of files to add to the generated CTF archive. Independent of
        % the length of FCN -- all files are accessible to every tool in 
        % the archive.
        opts.files string {prodserver.mcp.validation.mustBeVectorOrEmpty} = string.empty

        % MCP tool definition. Generated if not provided. If provided, must
        % be the same size as FCN.
        opts.definition {prodserver.mcp.validation.mustBeToolDefinition} = string.empty

        % Exercise functions for schema generation. If provided, build()
        % calls prodserver.mcp.schema() internally to generate definitions.
        % Incompatible with the "definition" option.
        opts.example {prodserver.mcp.validation.mustBeExampleSpecification} = []

        % Maximum number of elements in a literal variable. Variables
        % larger than this are passed by reference via URLs.
        opts.maxLiteralSize (1,1) double = prodserver.mcp.MCPConstants.MaxLiteralSize;

        % Wire encoding. A scalar applies to all tools, or specify a vector
        % the same length as the number of tools to give each tool its own
        % encoding strategy. Default: plain JSON encoding.
        opts.encoding prodserver.mcp.WireEncoding = "JSON";

        % MCP server resources. A structure with at least two fields: uri
        % and contents. Allow a struct array or a cell array.
        opts.resource (1,:) struct {prodserver.mcp.validation.mustBeResource} = []

        % MCP App HTML file. Registers as a ui:// resource with MIME type
        % text/html;profile=mcp-app and injects _meta.ui.resourceUri into
        % user tool definitions. One file; "" means no app.
        opts.app string {mustBeScalarOrEmpty, prodserver.mcp.validation.mustBeFileOrEmpty} = string.empty

        % Embed routes in archive or use MPS instance-global routes?
        opts.routes prodserver.mcp.RoutesType = prodserver.mcp.RoutesType.Archive

        % ImportOptions objects for auto-generated wrapper functions.
        opts.import {prodserver.mcp.validation.mustBeArgImport} = struct.empty

        % Wrapper function for marshaling large data as files.
        opts.wrapper string {prodserver.mcp.validation.mustBeWrapper} = repmat(prodserver.mcp.MCPConstants.AutoWrapper, 1, numel(fcn))

        % Map of MATLAB to JSON types used in description generation. A
        % scalar struct. Fieldnames are MATLAB type names, values are JSON
        % type names. Applies to all generated descriptions.
        opts.typemap struct {mustBeScalarOrEmpty} = []

        % Timeout, in seconds, for server interactions.
        opts.timeout (1,1) double = 30

        % Number of times to retry operations that time out.
        opts.retry (1,1) double = 2

        % Stage at which to stop the build process. Useful for testing.
        opts.stop (1,1) prodserver.mcp.BuildStage = prodserver.mcp.BuildStage.Deploy

        % Include discovery metadata in archive for /api/discovery endpoint.
        opts.discovery (1,1) logical = true
    end

    import prodserver.mcp.MCPConstants

    if ~isempty(opts.example) && ~isempty(opts.definition)
        error("prodserver:mcp:ExampleDefinitionConflict", ...
            "Cannot specify both 'example' and 'definition'. " + ...
            "Use 'example' to generate definitions via observation, " + ...
            "or 'definition' to provide pre-built definitions, but not both.");
    end

    % wrapper takes one entry per function, or a single keyword ("Auto",
    % "None", or "" to always generate) that applies to all of them. One
    % wrapper file cannot serve several functions, so that case is left
    % for wrapForMCP's size check. Match fcn's shape, so a column of
    % functions works with the row default.
    if isscalar(opts.wrapper) && ~isscalar(fcn) && ...
            any(strcmpi(opts.wrapper, ...
                [MCPConstants.AutoWrapper, MCPConstants.NoWrapper, ""]))
        opts.wrapper = repmat(opts.wrapper, size(fcn));
    elseif numel(opts.wrapper) == numel(fcn)
        opts.wrapper = reshape(opts.wrapper, size(fcn));
    end

    % encoding takes one entry for all the functions, or one per function.
    % A row, as the tool lists built from it are.
    if isscalar(opts.encoding)
        opts.encoding = repmat(opts.encoding, 1, numel(fcn));
    elseif numel(opts.encoding) == numel(fcn)
        opts.encoding = reshape(opts.encoding, 1, []);
    else
        error("prodserver:mcp:SizeMismatch", "Specify one encoding for " + ...
            "all the functions or one per function, not %d encodings " + ...
            "for %d functions.", numel(opts.encoding), numel(fcn));
    end

    % A definition observed from examples names the original function as
    % the tool's entry point and describes its arguments, not a wrapper's.
    % A wrapper would be built into the archive and never called, so
    % refuse an explicit one and, by default, build no wrapper at all.
    if ~isempty(opts.example)
        explicit = ~strcmpi(opts.wrapper, MCPConstants.AutoWrapper) & ...
            ~strcmpi(opts.wrapper, MCPConstants.NoWrapper);
        if any(explicit)
            error("prodserver:mcp:ExampleWrapperConflict", ...
                "Cannot combine 'example' with a wrapper function. " + ...
                "Definitions generated from examples call the original " + ...
                "function directly. Omit 'wrapper' or set it to ""%s"".", ...
                MCPConstants.NoWrapper);
        end
        opts.wrapper = repmat(MCPConstants.NoWrapper, size(fcn));
    end

    % A zero-length app is no app.
    if ~isempty(opts.app) && strlength(opts.app) == 0
        opts.app = string.empty;
    end

    % Might be zero-length strings, depending on final stage executed.
    ctf = "";
    endpoint = "";

    % build puts folders at the front of the path as it needs them, and
    % restores the path when it's done.
    pth = path;
    restorePath = onCleanup(@()path(pth));

    % The built-in tools must be on the path, and framework functions that
    % build finds by name must belong to this copy of the framework.
    root = prodserver.mcp.internal.packageFolder();
    prodserver.mcp.internal.prependPath(fullfile(root,"server","tools"));
    checkShadowing(root, ~isempty(opts.app));

    % Determine path to user-supplied function(s)
    files = arrayfun(@(f)string(which(f)),fcn);
    notFound = strlength(files) == 0;
    if any(notFound)
        nope = find(notFound,1);
        error("prodserver:mcp:ToolNotFound", ...
            "Could not locate file for function '%s'.", fcn(nope));
    end

    % Make sure all additional files exist.
    notFound = arrayfun(@(af)exist(af,"file") == 0,opts.files);
    if any(notFound)
        nope = find(notFound,1);
        error("prodserver:mcp:AdditionalFileNotFound", ...
            "Could not locate file '%s'.", opts.files(nope));
    else
        % Force opts.files into a vector with the same non-scalar dimension
        % as fcn.
        if isrow(files)
            extra = opts.files(:)';
            files = [files,extra];
        else
            extra = opts.files(:);
            files = [files;extra];
        end
    end
    
    % Make opts.folder directory if necessary. isfolder, not exist: exist
    % is also nonzero for a MATLAB file or function of that name on the
    % path, so folder="addOne" was never made while building addOne.
    if ~isfolder(opts.folder)
        [ok,msg] = mkdir(opts.folder);
        if ~ok
            error("prodserver:mcp:InaccessibleOutputFolder", "Cannot " + ...
                "create or access output folder %s: %s", opts.folder, msg);
        end
    end

    % Generate definitions by observing example calls: once, whatever the
    % encodings, each function's schema then built with its own.
    if ~isempty(opts.example)
        opts.definition = prodserver.mcp.schema(fcn, opts.example, ...
            typemap=opts.typemap, encoding=opts.encoding);
    end

    % Not possible, currently, but in place just in case another, earlier
    % stage is developed later.
    if opts.stop < prodserver.mcp.BuildStage.Wrapper, return; end

    % Generate or copy wrappers for each MCP tool. fcn MUST NOT be a file
    % path, because wrapForMCP requires MATLAB-callable identifiers -- just
    % the function name in this case.
    [wrapper,defs] = prodserver.mcp.internal.wrapForMCP(fcn, ...
        opts.wrapper, opts.folder, timeout=opts.timeout, ...
        maxLiteralSize=opts.maxLiteralSize, retry=opts.retry,...
        import=fieldnames(opts.import),typemap=opts.typemap, ...
        encoding=opts.encoding);

    if ~isempty(wrapper)
        files = [files, wrapper];
    end

    % Save wrapper file argument importer 
    appendDefinition = {};
    if isempty(opts.import) == false
        def.(MCPConstants.ImporterVariable) = opts.import;
        definitionFile = fullfile(opts.folder,MCPConstants.DefinitionFile);
        save(definitionFile,"-struct","def");
        appendDefinition = {"-append"};
    end

    % Put the output folder on the path so that defineForMCP can find the
    % wrapper function.
    prodserver.mcp.internal.prependPath(opts.folder);

    % If no wrapper, tool calls fcn
    if isempty(wrapper)
        wrapperFcn = opts.tool;
    else
        [~,wrapperFcn] = fileparts(wrapper);
    end

    % Only generate definition if stop-stage permits it. Definition
    % includes both tools and resources. There's no way to generate only
    % tools or only resources.
    if opts.stop < prodserver.mcp.BuildStage.Definition, return; end

    % All servers have a tool that reads resources because some agent
    % environments (Claude desktop and Claude Code as of April 2026) cannot
    % actually retrieve bare resources. 

    toolList = [opts.tool, MCPConstants.ReadResourceTool];
    wrapperFcn = [wrapperFcn, MCPConstants.ReadResourceTool];
    enc = opts.encoding;
    if isscalar(enc)
        enc = repmat(enc,size(opts.tool));
    end
    wireEncoding = [enc, "JSON"];
    % Empty defs for resource reader, since no wrapper.
    if ~isempty(defs)
        defs = [defs {[]}];
    end

    % Add full path to the tool to the list of files built into the CTF
    files = [files, which(MCPConstants.ReadResourceTool)];

    % Servers with an MCP App include uri2json so the app can read data
    % from URIs returned by tools.
    if ~isempty(opts.app)
        toolList = [toolList, MCPConstants.Uri2JsonTool];
        wrapperFcn = [wrapperFcn, MCPConstants.Uri2JsonTool];
        wireEncoding = [wireEncoding, "JSON"];
        if ~isempty(defs)
            defs = [defs {[]}];
        end
        files = [files, which(MCPConstants.Uri2JsonTool)];
    end

    defArgs = {};
    % defineForMCP expects opts.definition to provide a COMPLETE definition
    % of each tool. The definition must be a file, JSON string or a
    % structure.
    if ~isempty(opts.definition)
        definition = num2cell(opts.definition);
        % No definitions for the built-in tools (resource reader, and
        % uri2json with an app): defineForMCP generates them.
        definition(end+1:numel(toolList)) = {[]};
        defArgs = {"definition", definition};
    elseif ~isempty(defs)
        defArgs = {"defs", defs};
    end
    definition = prodserver.mcp.internal.defineForMCP(toolList, ...
        wrapperFcn,defArgs{:},encoding=wireEncoding, typemap=opts.typemap, ...
        stage=prodserver.mcp.BuildStage.Definition);

    % Include the wire-encoding resource only when at least one tool uses
    % Invertible encoding.
    if any(wireEncoding == "Invertible")
        resourceList = { MCPConstants.WireEncodingResource };
    else
        resourceList = {};
    end

    % Cell array because fields of each resource structure may vary.
    yours = false(size(resourceList));
    if ~isempty(opts.resource)
        resourceList = [ resourceList, num2cell(opts.resource) ];
        yours = [yours, true(1, numel(opts.resource))];
    end

    % Build app resources and inject _meta.ui into tool definitions.
    [appResources, appUriMap] = buildAppResources( ...
        opts.app, opts.archive, opts.tool);
    resourceList = [resourceList, appResources];
    yours = [yours, false(size(appResources))];

    % Your resources were checked against each other when build was
    % called. Nor may they reuse a URI of the framework's own resources.
    if any(yours)
        uris = cellfun(@(r) string(r.uri), resourceList);
        reused = intersect(uris(yours), uris(~yours));
        if ~isempty(reused)
            error("prodserver:mcp:DuplicateResourceURI", ...
                "The framework's own resources use the URI '%s'. A URI " + ...
                "must identify exactly one resource: give yours another.", ...
                reused(1));
        end
    end

    nUserTools = numel(opts.tool);
    for n = 1:nUserTools
        if strlength(appUriMap(n)) > 0
            definition.tools{n}.(MCPConstants.MetaField).ui.resourceUri = appUriMap(n);
        end
    end

    if any(strlength(appUriMap) > 0)
        def.(MCPConstants.AppResourceVariable) = true;
    end

    % uri2json is for the view, not the model: hosts that support MCP Apps
    % keep an app-only tool out of the model's tool list. A cell, so that
    % it's encoded as the JSON array the spec requires, not a string.
    if ~isempty(opts.app)
        u = find(cellfun(@(t) string(t.name) == MCPConstants.Uri2JsonTool, ...
            definition.tools), 1);
        definition.tools{u}.(MCPConstants.MetaField).ui.visibility = {'app'};
    end

    % Generate resource definitions and add them to the structure saved
    % into the MCP definition file.
    resources = prodserver.mcp.internal.resourceDefinition(resourceList);
    def.(MCPConstants.ResourceVariable) = resources;

    % Save the definition to deploy with the MCP tool. -struct saves the
    % fields of the structure as named variables. "def" itself does not
    % become a name.
    def.(MCPConstants.DefinitionVariable) = definition;
    definitionFile = fullfile(opts.folder,MCPConstants.DefinitionFile);
    save(definitionFile,"-struct","def",appendDefinition{:});

    % Build the MCP-enabled CTF archive unless stop-stage prevents it.
    ctf = buildMCP(files,opts.folder,opts.archive,definitionFile, ...
        opts.routes, opts.stop, opts.discovery);

    % If a server was provided, publish the archive to the server.
    if opts.stop < prodserver.mcp.BuildStage.Deploy, return; end
    if ~isempty(opts.server)
        endpoint = prodserver.mcp.deploy(ctf,opts.server);
    end
end

function tf = mustBeServerOrEmpty(x)
    tf = isempty(x);
    if tf == false
        prodserver.mcp.validation.mustBeServer(x);
    end
end

function [resources, uriMap] = buildAppResources(app, archive, tools)
    import prodserver.mcp.MCPConstants
    resources = {};
    uriMap = repmat("", size(tools));
    if ~isempty(app)
        appUri = "ui://" + archive + "/" + archive + ".html";
        % Read the view here. Given its path, resourceDefinition would read
        % the file only if the path passed its own checks, and otherwise
        % serve the path itself as the view.
        appResource = struct('uri', appUri, ...
            'contents', prodserver.mcp.internal.readUTF8(app), ...
            'name', archive + "-app", ...
            'mimeType', MCPConstants.AppResourceMimeType);
        resources = {appResource};
        uriMap(:) = appUri;
    end
end

function handlers = routeHandlers()
%routeHandlers The functions bound directly to the web routes.
    handlers = [ ...
        "prodserver.mcp.internal.mcpHandler", ...   % MCP protocol
        "prodserver.mcp.internal.pingHandler", ...  % Ping request
        "prodserver.mcp.internal.signatureHandler" ... % Function signatures
        ];
end

function checkShadowing(root, withApp)
%checkShadowing Make sure that the framework functions build finds by name
%belong to the framework in root. Another copy of the framework earlier on
%the path, or a user function with the same name, would otherwise be built
%into the archive in their place. With an app, that includes uri2json.
    import prodserver.mcp.internal.canonicalFolder
    fcns = [routeHandlers(), prodserver.mcp.MCPConstants.ReadResourceTool];
    if withApp
        fcns = [fcns, prodserver.mcp.MCPConstants.Uri2JsonTool];
    end
    croot = canonicalFolder(root);
    root = strip(root, "right", filesep);
    for n = 1:numel(fcns)
        file = string(which(fcns(n)));
        if strlength(file) == 0
            error("prodserver:mcp:FrameworkShadowed", ...
                "Framework function %s isn't on the MATLAB path, so the " + ...
                "framework in use at %s is incomplete.", fcns(n), root);
        end
        folder = canonicalFolder(fileparts(file));
        if ~startsWith(folder + filesep, croot + filesep)
            % The path entry is the folder above any namespace folders.
            entry = string(fileparts(file));
            if contains(entry, filesep + "+")
                entry = extractBefore(entry, filesep + "+");
            end
            % The current folder comes before the path, on it or not.
            if canonicalFolder(entry) == canonicalFolder(string(pwd))
                fix = sprintf("It is in the current folder, which " + ...
                    "MATLAB searches first: change to another folder, " + ...
                    "or rename the file.");
            else
                fix = sprintf("Remove %s from the MATLAB path, or " + ...
                    "rename the file.", entry);
            end
            error("prodserver:mcp:FrameworkShadowed", ...
                "Framework function %s resolves to %s, outside the " + ...
                "framework in use at %s. %s", fcns(n), file, root, fix);
        end
    end
end

function name = basename(fcn)
%basename The base name (function name) of fcn. fcn may be the name of a
%function on the path or the full or relative path to a file. fcn may be a
%vector.
    arguments
        fcn string
    end
    
    function n = fcnName(fcn)
        % If fcn does not specify a path to an existing file, try locating
        % it with which.
        if exist(fcn,"file") == 0
            fcn = which(fcn);
        end
        [~,n] = fileparts(fcn);
    end
            
    % Any names that were not found will create "" entries in name.
    name = arrayfun(@(f)fcnName(f),fcn);
end

function ctf = buildMCP(files, folder, archive, definition, routesType, stop, discovery)
%buildMCP Create a Model Context Protocol-enabled CTF archive for MATLAB
%Production Server.

    % Zero-length string if the stop stage is < Archive
    ctf = "";

    % buildMCP produces the routes file and the archive.
    if stop < prodserver.mcp.BuildStage.Routes, return; end

    % Copy boiler-plate routes files into customer-provided deployment
    % artifact folder (which must exist). Copy even if targets are
    % read-only.
    root = fileparts(mfilename("fullpath"));
    [status, msg] = copyfile(fullfile(root,"+internal","*_routes.json"), ...
        folder,"f");
    if status == 0
        error("prodserver:mcp:CopyRoutesFailed", "Failed to copy " + ...
            "web routing files into '%s': %s", folder, msg);
    end

    % Edit the instance routes file to replace <ArchiveName> with the 
    % name of the archive.
    grFile = fullfile(folder,"instance_routes.json");
    prodserver.mcp.internal.replaceStringsInFile(grFile,"<Archive>", ...
        archive);

    % Edit the Dev and Test routes file to set the archive name.
    dtrFile = fullfile(folder,"dev_test_routes.json");
    prodserver.mcp.internal.replaceStringsInFile(dtrFile,"<Archive>", ...
        archive);

    % No error checking here, because the only caller is build, whom we
    % assume makes no mistakes.
    if ismember(prodserver.mcp.RoutesType.Archive,routesType)
        args = { "RoutesFile", fullfile(folder,"archive_routes.json") };
    else
        args = {};
    end

    % If we're running in a sandbox, turn off warnings about non-deployable
    % files.
    if prodserver.mcp.internal.isSandbox()
        id = 'MATLAB:depfun:req:UndeployableSymbol';
        status = warning('query',id);
        warning('off', id);
        restoreUndeployable = onCleanup(@()warning(status.state,id));
    end

    % MATLAB Compiler briefly puts the folder of each function it inspects
    % at the front of the path. For the handlers below, that folder is the
    % package root, which an installed add-on requires to come after its
    % member folders, so every inspection warns.
    reorderID = 'MATLAB:mpath:PackagesBrokenAsAtomicUnitDueToReorderedEntries';
    reorderState = warning('off', reorderID);
    restoreReorder = onCleanup(@()warning(reorderState));

    % I/O scheme management subclasses are invoked indirectly and thus
    % impossible for MATLAB Compiler to find by inspection. Assemble a list
    % of them and build them into the archive via "AdditionalFiles". Each
    % Scheme subclass has an associated YAML file -- bring those along too.
    schemes = prodserver.mcp.io.Scheme.SchemeClasses("get");
    schemes = arrayfun(@(s)string(which(s)),schemes);
    yaml = arrayfun(@(s)replace(s,".m"+textBoundary("end"),".yaml"), schemes);
    schemes = [ schemes, yaml ];

    % The marshaller dispatches I/O to functions named in YAML configs.
    % These are invisible to MATLAB Compiler — resolve and include them.
    mu = prodserver.mcp.io.MarshallURI();
    dlg = delegates(mu);
    dlg = arrayfun(@(f)string(which(f)), dlg);
    dlg = dlg(strlength(dlg) > 0 & ~startsWith(dlg, ["built-in", matlabroot]));
    schemes = [schemes, dlg];

    % Protocol adapter subclasses are discovered via meta.package
    % introspection at runtime, invisible to MATLAB Compiler. Resolve
    % all classes and functions in each adapter's package so the CTF
    % includes the entire drop-in package for each protocol version.
    adapterNames = prodserver.mcp.protocol.ProtocolRegistry.adapterClasses();
    adapterPkgFiles = string.empty;
    for ai = 1:numel(adapterNames)
        parts = split(adapterNames(ai), ".");
        pkgName = join(parts(1:end-1), ".");
        subpkg = meta.package.fromName(pkgName);
        for ci = 1:numel(subpkg.ClassList)
            adapterPkgFiles(end+1) = string(which(subpkg.ClassList(ci).Name)); %#ok<AGROW>
        end
        for fi = 1:numel(subpkg.FunctionList)
            adapterPkgFiles(end+1) = string(which(subpkg.FunctionList(fi).Name)); %#ok<AGROW>
        end
    end
    adapterPkgFiles = unique(adapterPkgFiles);
    adapterPkgFiles = adapterPkgFiles( ...
        strlength(adapterPkgFiles) > 0 & ...
        ~startsWith(adapterPkgFiles, ["built-in", matlabroot]));
    if isempty(adapterPkgFiles)
        error('prodserver:mcp:NoAdapterFiles', ...
            'No deployable files found for protocol adapters.');
    end

    % Shared handlers are dispatched via feval with function names from
    % a dictionary, invisible to MATLAB Compiler. Resolve them from the
    % dispatcher's single source of truth.
    dispatcherFiles = ...
        prodserver.mcp.handler.ProtocolDispatcher.instance().handlerFiles();

    % Add the custom route handling functions. These are bound directly
    % to the web routes.
    handlers = routeHandlers();

    % Package platform-specific binaries. Package all platforms, to reduce
    % the chance of creating a platform-specific archive. This allows an
    % archive created on Linux to be deployed to a server running on
    % Windows, for example.

    % Get the folder that contains all the architecture-specific folders.
    [~,binFolder] = prodserver.mcp.internal.packageFolder();
    binParent = fullfile(binFolder,"..");

    % Find all the architecture-specific folders. This avoids a hard-coded
    % list, which we'd have to change as platforms go in and out of
    % support.
    archFolders = dir(binParent);
    archFolders = archFolders([archFolders.isdir]);
    archFolders = string({ archFolders.name });
    archFolders = archFolders(~matches(archFolders,[".",".."]));

    % Assemble a list of the executables in each architecture-specific
    % folder.
    exeFiles = ["persist/file_persist", "yaml2json/yaml2json"];
    binFiles = strings(1,numel(archFolders)*numel(exeFiles));
    for ad = 1:numel(archFolders)
        af = fullfile(binParent,archFolders(ad));
        bf = fullfile(af,exeFiles);
        % Assumes that all current and future Windows-specific folder
        % names will start with 'win'. Bit of risk, but a very small bit.
        if startsWith(archFolders(ad),"win")
            bf = bf + ".exe";
        end
        binFiles(ad*2-1:ad*2) = bf;
    end

    discoveryArgs = {};
    if discovery
        discoveryFile = prodserver.mcp.internal.discoverySignatures( ...
            folder, archive);
        discoveryArgs = {"FunctionSignatures", discoveryFile};
    end

    if stop < prodserver.mcp.BuildStage.Archive, return; end

    % This is a terrible, temporary, solution to a complex problem. It must
    % be removed when the schema management change is integrated with the
    % main release branch.last
    excludeState = warning('off','Compiler:compiler:COM_WARN_EXCLUDED_FILE');
    restoreExcluded = onCleanup(@()warning(excludeState));

    % Can't suppress the text emitted by MATLAB Compiler, since
    % ProductionServerArchiveOptions has no way to suppress a warning.
    % This is the way to suppress it when calling MCC directly:
    %      -w disable:Compiler:compiler:COM_WARN_EXCLUDED_FILE

    hFiles = arrayfun(@(fcn)string(which(fcn)),handlers);

    opts = compiler.build.ProductionServerArchiveOptions(hFiles, ...
        args{:}, discoveryArgs{:}, ArchiveName=archive, ...
        AdditionalFiles=[definition, files, schemes, adapterPkgFiles, dispatcherFiles, binFiles], ...
        OutputDir=folder);
    results = compiler.build.productionServerArchive(opts);
    ctf = string(results.Files{1});
end



