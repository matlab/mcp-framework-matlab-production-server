function shadowDir = generateShadow(fcns)
%generateShadow Create shadow wrapper functions for path-shadowing observation.
%   Generates varargin/varargout wrappers in a temporary folder and returns
%   the folder path. Each wrapper records argument schemas via the
%   SchemaObserver stored in getappdata(0), then forwards to the original
%   function by temporarily removing the shadow folder from the path.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.internal.metafunction

    shadowDir = fullfile(tempdir, "mcp_schema_shadow_" + ...
        char(java.util.UUID.randomUUID()));
    mkdir(shadowDir);

    for i = 1:numel(fcns)
        fcnName = fcns(i);
        mf = metafunction(fcnName);

        % Collect positional input argument names.
        % Positional = no GroupName (both required and optional-positional).
        % NVP names are read from varargin at runtime, not baked in.
        inputNames = string.empty;
        for p = 1:numel(mf.Signature.Inputs)
            if strlength(string(mf.Signature.Inputs(p).Identifier.GroupName)) == 0
                inputNames(end+1) = string(mf.Signature.Inputs(p).Identifier.Name); %#ok<AGROW>
            end
        end
        nPositional = numel(inputNames);

        % Collect output argument names (always positional in MATLAB)
        outputNames = arrayfun(@(p) string(p.Identifier.Name), ...
            mf.Signature.Outputs);

        % Generate the shadow function code
        code = generateCode(fcnName, shadowDir, ...
            inputNames, nPositional, outputNames, numel(outputNames));

        % Write to file
        filePath = fullfile(shadowDir, fcnName + ".m");
        fid = fopen(filePath, 'w');
        fprintf(fid, '%s', code);
        fclose(fid);
    end
end

function code = generateCode(fcnName, shadowDir, inputNames, nPositional, ...
    outputNames, nOutputPositional)

    % Escape the shadow directory path for use in generated code.
    % Use forward slashes to avoid backslash escaping issues in sprintf.
    escapedDir = strrep(shadowDir, '\', '/');
    escapedDir = strrep(escapedDir, '''', '''''');

    % Format argument name arrays as string literals
    inNamesStr = formatStringArray(inputNames);
    outNamesStr = formatStringArray(outputNames);

    code = sprintf([...
        'function [varargout] = %s(varargin)\n' ...
        '    obs = getappdata(0, ''MCPSchemaObserver'');\n' ...
        '    obs.record("%s", "input", %s, varargin, %d);\n' ...
        '\n' ...
        '    rmpath(''%s'');\n' ...
        '    try\n' ...
        '        [varargout{1:nargout}] = %s(varargin{:});\n' ...
        '    catch ex\n' ...
        '        addpath(''%s'');\n' ...
        '        rethrow(ex);\n' ...
        '    end\n' ...
        '    addpath(''%s'');\n' ...
        '\n' ...
        '    obs.record("%s", "output", %s, varargout, %d);\n' ...
        'end\n'], ...
        fcnName, ...
        fcnName, inNamesStr, nPositional, ...
        escapedDir, ...
        fcnName, ...
        escapedDir, ...
        escapedDir, ...
        fcnName, outNamesStr, nOutputPositional);
end

function s = formatStringArray(names)
    if isempty(names)
        s = 'string.empty';
    elseif numel(names) == 1
        s = '"' + names(1) + '"';
    else
        quoted = arrayfun(@(n) '"' + n + '"', names);
        s = '[' + strjoin(quoted, ',') + ']';
    end
end
