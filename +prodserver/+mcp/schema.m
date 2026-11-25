function definitions = schema(fcns, example, opts)
%schema Generate MCP tool schemas by observing function calls at runtime.
%   Creates shadow wrappers that intercept calls to the specified functions,
%   records argument types as JSON Schema fragments, then merges them into
%   complete tool definitions compatible with prodserver.mcp.build().
%
%   definitions = prodserver.mcp.schema(fcns, example)
%   definitions = prodserver.mcp.schema(fcns, example, typemap=tm)
%   definitions = prodserver.mcp.schema(fcns, example, encoding=enc)
%
%   fcns    - String vector of function names to observe (must be on path).
%   example - What to run. Accepts function handles, file paths (.m),
%             folder paths, or function/script names. All examples run
%             sequentially; no pairing with fcns required.
%   enc     - Wire encoding: one for all of fcns, or one per function.
%             The examples run once either way.
%
%   The returned definitions struct is directly usable as:
%       prodserver.mcp.build(fcns, definition=definitions)

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        fcns string {mustBeNonempty}
        example {prodserver.mcp.validation.mustBeExampleSpecification, mustBeNonempty}
        opts.typemap struct {mustBeScalarOrEmpty} = []
        opts.encoding prodserver.mcp.WireEncoding {mustBeVector} = "JSON"
    end

    import prodserver.mcp.internal.SchemaObserver
    import prodserver.mcp.internal.generateShadow
    import prodserver.mcp.internal.classifyExample

    if ~isscalar(opts.encoding) && numel(opts.encoding) ~= numel(fcns)
        error("prodserver:mcp:SizeMismatch", "Specify one encoding for " + ...
            "all the functions or one per function, not %d encodings " + ...
            "for %d functions.", numel(opts.encoding), numel(fcns));
    end

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
    prodserver.mcp.internal.prependPath(originalDir);
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

    % The variables of the original closure and the bound handles, the
    % only variables the new handle may see.
    vars = boundHandles;
    if ~isempty(f.workspace)
        ws = f.workspace{1};
        wsFields = fieldnames(ws);
        for k = 1:numel(wsFields)
            vars.(wsFields{k}) = ws.(wsFields{k});
        end
    end

    example = evalExample(expr, vars);
end

function mcp__example__ = evalExample(mcp__expr__, mcp__vars__)
%evalExample Make the handle MCP__EXPR__ in a workspace holding only the
%   variables in the struct MCP__VARS__. Not in rebindExample's: there, a
%   name in the expression that isn't a variable of the closure sees
%   rebindExample's own variable of that name. The loop index i turned
%   2+i into 3, and an undefined k became 1. Every name of this function's
%   own starts mcp__, as the bound handles' do, so none can stand in for a
%   name the example uses.
    for mcp__name__ = string(fieldnames(mcp__vars__))'
        eval(mcp__name__ + " = mcp__vars__.(mcp__name__);");
    end
    mcp__example__ = eval(mcp__expr__);
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
