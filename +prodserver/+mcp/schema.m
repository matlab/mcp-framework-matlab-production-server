function definitions = schema(fcns, tests, opts)
%schema Generate MCP tool schemas by observing function calls at runtime.
%   Creates shadow wrappers that intercept calls to the specified functions,
%   records argument types as JSON Schema fragments, then merges them into
%   complete tool definitions compatible with prodserver.mcp.build().
%
%   definitions = prodserver.mcp.schema(fcns, tests)
%   definitions = prodserver.mcp.schema(fcns, tests, typemap=tm)
%
%   fcns  - String vector of function names to observe (must be on path).
%   tests - What to run. Accepts function handles, test file paths (.m),
%           test folder paths, or function/script names. All tests run
%           sequentially; no pairing with fcns required.
%
%   The returned definitions struct is directly usable as:
%       prodserver.mcp.build(fcns, definition=definitions)

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        fcns string {mustBeNonempty}
        tests {prodserver.mcp.validation.mustBeTestSpecification, mustBeNonempty}
        opts.typemap struct {mustBeScalarOrEmpty} = []
        opts.encoding (1,1) prodserver.mcp.WireEncoding = "JSON"
    end

    import prodserver.mcp.internal.SchemaObserver
    import prodserver.mcp.internal.generateShadow
    import prodserver.mcp.internal.classifyTest

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

    % Generate shadow wrappers and add to path
    shadowDir = generateShadow(fcns);
    pth = path;
    shadows = onCleanup(@()cleanup(shadowDir,pth));
    addpath(shadowDir);

    % onCleanup ensures exception safety.
    classifyTest(tests);

    % Remove shadows before harvest or metafunction will analyze the shadow
    % function.
    delete(shadows);
   
    % Harvest schemas into definition structs
    definitions = obs.harvest(fcns, opts.encoding);
end

function cleanup(shadowDir,pth)
    path(pth);
    if isappdata(0, 'MCPSchemaObserver')
        rmappdata(0, 'MCPSchemaObserver');
    end
    if isfolder(shadowDir)
        rmdir(shadowDir, 's');
    end
end
