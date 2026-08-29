function definitions = schema(fcns, example, opts)
%schema Generate MCP tool schemas by observing function calls at runtime.
%   Creates shadow wrappers that intercept calls to the specified functions,
%   records argument types as JSON Schema fragments, then merges them into
%   complete tool definitions compatible with prodserver.mcp.build().
%
%   definitions = prodserver.mcp.schema(fcns, example)
%   definitions = prodserver.mcp.schema(fcns, example, typemap=tm)
%
%   fcns    - String vector of function names to observe (must be on path).
%   example - What to run. Accepts function handles, file paths (.m),
%             folder paths, or function/script names. All examples run
%             sequentially; no pairing with fcns required.
%
%   The returned definitions struct is directly usable as:
%       prodserver.mcp.build(fcns, definition=definitions)

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        fcns string {mustBeNonempty}
        example {prodserver.mcp.validation.mustBeExampleSpecification, mustBeNonempty}
        opts.typemap struct {mustBeScalarOrEmpty} = []
        opts.encoding (1,1) prodserver.mcp.WireEncoding = "JSON"
    end

    import prodserver.mcp.internal.SchemaObserver
    import prodserver.mcp.internal.generateShadow
    import prodserver.mcp.internal.classifyExample

    % Verify all functions exist on the path
    for i = 1:numel(fcns)
        if exist(fcns(i), "file") == 0
            error("prodserver:mcp:SchemaFcnNotFound", ...
                "Function '%s' not found on the MATLAB path.", fcns(i));
        end
    end

    % Create observer and install in appdata
    obs = SchemaObserver(opts.typemap);
    setappdata(0, 'MCPSchemaObserver', obs);

    % Capture pre-bound handles to the real functions while the path is
    % clean. Shadow wrappers call through these handles to reach the real
    % implementation without infinite recursion.
    for i = 1:numel(fcns)
        setappdata(0, "mcp__realHandle__" + fcns(i), str2func(fcns(i)));
        setappdata(0, "mcp__inCall__" + fcns(i), false);
    end

    % Generate shadow wrappers in a temp folder and cd there so that
    % shadows are in pwd (which always wins for function resolution).
    % Add the original pwd to the path so data files remain accessible.
    shadowDir = generateShadow(fcns);
    pth = path;
    originalDir = pwd;
    shadows = onCleanup(@()cleanup(shadowDir, pth, originalDir, fcns));
    addpath(originalDir);
    cd(shadowDir);

    % Rebind function handle examples so they resolve to the shadow.
    example = rebindExample(example, fcns, shadowDir);

    % onCleanup ensures exception safety.
    classifyExample(example);

    % Remove shadows before harvest or metafunction will analyze the shadow
    % function.
    delete(shadows);

    % Harvest schemas into definition structs
    definitions = obs.harvest(fcns, opts.encoding);
end

function example = rebindExample(example, fcns, shadowDir)
%rebindExample Rebind function handle examples to use shadow wrappers.
%   For function handle examples, creates new handles where observed
%   function names resolve to the shadow directory. This ensures the
%   shadow intercepts calls even from pre-bound anonymous handles.

    if iscell(example)
        for i = 1:numel(example)
            example{i} = rebindExample(example{i}, fcns, shadowDir);
        end
        return;
    end

    if ~isa(example, 'function_handle')
        return;
    end

    f = functions(example);
    expr = f.function;

    % Build bound handles: str2func(name) while in shadowDir permanently
    % binds to the shadow file.
    boundHandles = struct();
    originalDir = pwd;
    cd(shadowDir);
    for i = 1:numel(fcns)
        boundHandles.("mcp__bound__" + fcns(i)) = str2func(char(fcns(i)));
    end
    cd(originalDir);

    % Replace each observed function name in the expression with its
    % bound variable name. The regex requires:
    %   lookbehind: ) , ( [ ; = space + - * (call context characters)
    %   lookahead:  ( (confirms it is a function call)
    modified = false;
    for i = 1:numel(fcns)
        pattern = '(?<=\)|,|\(|\[|;|=| |\+|-|\*)' + fcns(i) + '(?=\()';
        varName = "mcp__bound__" + fcns(i);
        newExpr = regexprep(expr, pattern, varName);
        if ~strcmp(newExpr, expr)
            expr = newExpr;
            modified = true;
        end
    end

    if ~modified
        return;
    end

    % Inject workspace variables from the original closure and the bound
    % handles, then eval the rewritten expression to create a new handle.
    vars = boundHandles;
    if ~isempty(f.workspace)
        ws = f.workspace{1};
        wsFields = fieldnames(ws);
        for k = 1:numel(wsFields)
            vars.(wsFields{k}) = ws.(wsFields{k});
        end
    end

    % Assign all variables into this workspace for eval
    varFields = fieldnames(vars);
    for k = 1:numel(varFields)
        eval([varFields{k} ' = vars.(varFields{k});']);
    end

    example = eval(expr);
end

function cleanup(shadowDir, pth, originalDir, fcns)
    cd(originalDir);
    path(pth);
    for i = 1:numel(fcns)
        key = "mcp__realHandle__" + fcns(i);
        if isappdata(0, key)
            rmappdata(0, key);
        end
        key = "mcp__inCall__" + fcns(i);
        if isappdata(0, key)
            rmappdata(0, key);
        end
    end
    if isappdata(0, 'MCPSchemaObserver')
        rmappdata(0, 'MCPSchemaObserver');
    end
    if isfolder(shadowDir)
        rmdir(shadowDir, 's');
    end
end
