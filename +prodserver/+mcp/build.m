function [ctf,endpoint] = build(fcn, opts)
%build Create an MCP tool from fcn. Optionally deploy the tool to
%MATLAB Production Server.

% Copyright 2025, The MathWorks.

    arguments
        % Name of the function to be built into a tool.
        fcn string {prodserver.mcp.validation.mustBeFunction}

        % GenAI framework to use for auto-generation of code, if necessary
        opts.genai (1,1) prodserver.mcp.GenerativeAI = "None"

        % Deploy tool to this server, if given.
        opts.server string { mustBeServerOrEmpty } = string.empty 

        % Base name of generated deployable archive.
        opts.archive string = basename(fcn(1))

        % Name of MCP tool on server. May differ from FCN.
        opts.tool string = basename(fcn)

        % Folder in which to generate deployable archive and other files.
        opts.folder (1,1) string = "./deploy"

        % MCP tool definition. Generated if not provided.
        opts.definition {prodserver.mcp.validation.mustBeToolDefinition} = string.empty

        % Embed routes in archive or use MPS instance-global routes?
        opts.routes prodserver.mcp.RoutesType = prodserver.mcp.RoutesType.Archive

        % ImportOptions objects for auto-generated wrapper functions.
        opts.import {prodserver.mcp.validation.mustBeArgImport} = struct.empty

        % Wrapper function for marshaling large data as files.
        opts.wrapper string {prodserver.mcp.validation.mustBeWrapper} = strings(1,numel(fcn))

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
    endopint = "";

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
        nope = first(notFound);
        error("prodserver:mcp:ToolNotFound", ...
            "Could not locate file for function '%s'.", fcn(nope));
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
    wrapper = prodserver.mcp.internal.wrapForMCP(fcn, ...
        opts.wrapper, opts.folder, AI=availableAI, timeout=opts.timeout, ...
        retry=opts.retry,import=fieldnames(opts.import));
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
        restorePath = onCleanup(@()rmpath(opts.folder));
    end

    % If no wrapper, tool calls fcn
    if isempty(wrapper)
        wrapperFcn = opts.tool;
    else
        [~,wrapperFcn] = fileparts(wrapper);
    end

    % Only generate definition if stop-stage permits it.
    if opts.stop < prodserver.mcp.BuildStage.Definition, return; end

    definition = prodserver.mcp.internal.defineForMCP(opts.tool, ...
        wrapperFcn,AI=availableAI,definition=opts.definition,folder=opts.folder);

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

    % No error checking here, because the only caller is build, whom we
    % assume makes no mistakes.
    if routesType == prodserver.mcp.RoutesType.Archive
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

    hFiles = arrayfun(@(fcn)string(which(fcn)),handlers);
    opts = compiler.build.ProductionServerArchiveOptions(hFiles, ...
        args{:}, ArchiveName=archive, AdditionalFiles=[definition, ...
        files, schemes, binFiles], OutputDir=folder);
    results = compiler.build.productionServerArchive(opts);
    ctf = string(results.Files{1});
end



