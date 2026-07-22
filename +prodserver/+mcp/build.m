function [ctf,endpoint] = build(fcn, opts)
%build Create an MCP tool from fcn. Optionally deploy the tool to
%MATLAB Production Server.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        % Name of the function to be built into a tool.
        fcn string {prodserver.mcp.validation.mustBeFunction}

        % GenAI framework to use for auto-generation of code, if necessary
        opts.genai (1,1) prodserver.mcp.GenerativeAI = "None"

        % Deploy tool to this server, if given.
        opts.server string { mustBeServerOrEmpty } = string.empty 

        % Base name of generated deployable archive.
        opts.archive string = basename(fcn(1))

        % Name of MCP tool on server. May differ from FCN. But must always
        % be the same size as FCN.
        opts.tool string = basename(fcn)

        % Folder in which to generate deployable archive and other files.
        opts.folder (1,1) string = "./deploy"

        % List of files to add to the generated CTF archive. Independent of
        % the length of FCN -- all files are accessible to every tool in 
        % the archive.
        opts.files string {prodserver.mcp.validation.mustBeVectorOrEmpty} = string.empty

        % MCP tool definition. Generated if not provided. If provided, must
        % be the same size as FCN.
        opts.definition {prodserver.mcp.validation.mustBeToolDefinition} = string.empty

        % Maximum number of elements in a literal variable. Variables
        % larger than this are passed by reference via URLs.
        opts.maxLiteralSize (1,1) double = prodserver.mcp.MCPConstants.MaxLiteralSize;

        % Wire encoding. A scalar applies to all tools, or specify a vector
        % the same length as the number of tools to give each tool its own
        % encoding strategy. Default: precise, invertible encoding.
        opts.encoding prodserver.mcp.WireEncoding = "Invertible";

        % MCP server resources. A structure with at least two fields: uri
        % and contents. Allow a struct array or a cell array.
        opts.resource (1,:) struct {prodserver.mcp.validation.mustBeResource} = []

        % Embed routes in archive or use MPS instance-global routes?
        opts.routes prodserver.mcp.RoutesType = prodserver.mcp.RoutesType.Archive

        % ImportOptions objects for auto-generated wrapper functions.
        opts.import {prodserver.mcp.validation.mustBeArgImport} = struct.empty

        % Wrapper function for marshaling large data as files.
        opts.wrapper string {prodserver.mcp.validation.mustBeWrapper} = strings(1,numel(fcn))

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
    end

    import prodserver.mcp.MCPConstants

    % Might be zero-length strings, depending on final stage executed.
    ctf = "";
    endpoint = "";

    % Both wrapper and definition generation might use generative AI.
    if opts.genai == prodserver.mcp.GenerativeAI.None
        availableAI = prodserver.mcp.internal.findGenAI();
    else
        availableAI = opts.genai;
    end

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
    
    % Make opts.folder directory if necessary.
    if exist(opts.folder,"file") == false
        [ok,msg] = mkdir(opts.folder);
        if ~ok
            error("prodserver:mcp:InaccessibleOutputFolder", "Cannot " + ...
                "create or access output folder %s: %s", opts.folder, msg);
        end
    end

    % Not possible, currently, but in place just in case another, earlier
    % stage is developed later.
    if opts.stop < prodserver.mcp.BuildStage.Wrapper, return; end

    % Generate or copy wrappers for each MCP tool. fcn MUST NOT be a file
    % path, because wrapForMCP requires MATLAB-callable identifiers -- just
    % the function name in this case.
    [wrapper,defs] = prodserver.mcp.internal.wrapForMCP(fcn, ...
        opts.wrapper, opts.folder, AI=availableAI, timeout=opts.timeout, ...
        maxLiteralSize=opts.maxLiteralSize, retry=opts.retry,...
        import=fieldnames(opts.import),typemap=opts.typemap);

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
    if prodserver.mcp.internal.isOnPath(opts.folder) == false
        addpath(opts.folder);
        cleanUpUserFolderPath = onCleanup(@()rmpath(opts.folder));
    end

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
    builtin_tools_folder = fullfile(...
        prodserver.mcp.internal.packageFolder(),"server","tools");
    addpath(builtin_tools_folder);
    cleanUpBuiltinFolderPath = onCleanup(@()rmpath(builtin_tools_folder));
    % Empty defs for resource reader, since no wrapper.
    if ~isempty(defs)
        defs = [defs {[]}];
    end

    % Add full path to the tool to the list of files built into the CTF
    files = [files, which(MCPConstants.ReadResourceTool)];  

    defArgs = {};
    % defineForMCP expects opts.definition to provide a COMPLETE definition
    % of each tool. The definition must be a file, JSON string or a
    % structure.
    if ~isempty(opts.definition)
        definition = num2cell(opts.definition);
        definition{end+1} = [];
        defArgs = {"definition", definition};
    elseif ~isempty(defs)
        defArgs = {"defs", defs};
    end
    definition = prodserver.mcp.internal.defineForMCP(toolList, ...
        wrapperFcn,defArgs{:},AI=availableAI,encoding=wireEncoding, ...
        stage=prodserver.mcp.BuildStage.Definition);

    % All servers have a resource that describes the wire-encoding used for
    % tool parameters.
    resourceList = MCPConstants.WireEncodingResource;

    % Default resource value struct.empty(1,0) won't concatenate with any
    % structure, so test required. Cell array because fields of each
    % resource structure may vary.
    if ~isempty(opts.resource)
        resourceList = { resourceList, opts.resource };
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
        opts.routes, opts.stop);

    % If a server was provided, publish the archive to the server.
    if opts.stop < prodserver.mcp.BuildStage.Deploy, return; end
    if ~isempty(opts.server)
        endpoint = prodserver.mcp.deploy(opts.archive,opts.server);
    end
end

function tf = mustBeServerOrEmpty(x)
    tf = isempty(x);
    if tf == false
        prodserver.mcp.validation.mustBeServer(x);
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

function ctf = buildMCP(files, folder, archive, definition, routesType, stop)
%buildMCP Create a Model Context Protocol-enabled CTF archive for MATLAB
%Production Server.

    % Zero-length string if the stop stage is < Archive
    ctf = "";

    % buildMCP produces the routes file and the archive.
    if stop < prodserver.mcp.BuildStage.Routes, return; end

    % Copy boiler-plate routes files into customer-provided deployment
    % artifact folder (which must exist).
    root = fileparts(mfilename("fullpath"));
    copyfile(fullfile(root,"+internal","*_routes.json"),folder);

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
        restoreWarning = onCleanup(@()warning(status.state,id));
    end

    % I/O scheme management subclasses are invoked indirectly and thus
    % impossible for MATLAB Compiler to find by inspection. Assemble a list
    % of them and build them into the archive via "AdditionalFiles". Each
    % Scheme subclass has an associated YAML file -- bring those along too.
    schemes = prodserver.mcp.io.Scheme.SchemeClasses("get");
    schemes = arrayfun(@(s)string(which(s)),schemes);
    yaml = arrayfun(@(s)replace(s,".m"+textBoundary("end"),".yaml"), schemes);
    schemes = [ schemes, yaml ];

    % Add the custom route handling functions. These are bound directly
    % to the web routes.
    handlers = [ ...
        "prodserver.mcp.internal.mcpHandler", ...   % MCP protocol
        "prodserver.mcp.internal.pingHandler", ...  % Ping request
        "prodserver.mcp.internal.signatureHandler" ... % Function signatures
        ];

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

    if stop < prodserver.mcp.BuildStage.Archive, return; end

    % This is a terrible, temporary, solution to a complex problem. It must
    % be removed when the schema management change is integrated with the
    % main release branch.last
    excludeState = warning('off','Compiler:compiler:COM_WARN_EXCLUDED_FILE');
    restoreWarning = onCleanup(@()warning(excludeState));

    % Can't suppress the text emitted by MATLAB Compiler, since 
    % ProductionServerArchiveOptions has no way to suppress a warning. 
    % This is the way to suppress it when calling MCC directly: 
    %      -w disable:Compiler:compiler:COM_WARN_EXCLUDED_FILE 

    hFiles = arrayfun(@(fcn)string(which(fcn)),handlers);
    opts = compiler.build.ProductionServerArchiveOptions(hFiles, ...
        args{:}, ArchiveName=archive, AdditionalFiles=[definition, ...
        files, schemes, binFiles], OutputDir=folder);
    results = compiler.build.productionServerArchive(opts);
    ctf = string(results.Files{1});
end



