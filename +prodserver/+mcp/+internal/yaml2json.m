function json = yaml2json(yamlFile)
% yaml2json Read YAML file. Return JSON text. 
%
%    JSON = yaml2json(YAMLFILE) reads the text of YAMLFILE and converts it
%    to JSON. Conversion fails if YAMLFILE contains anything other than
%    valid YAML. 
%
% Convert the resulting JSON to a MATLAB structure with jsondecode.
%
% Example:
%
%    Read "/marshal/config/scheme.yaml" into a JSON string and convert it
%    to a MATLAB structure:
%
%       json = yaml2json("/marshal/config/scheme.yaml");
%       config = jsondecode(json);
%
% See also: struct2yaml, jsondecode

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.internal.redAlert

    bin = prodserver.mcp.internal.binFolder("yaml2json");

    name = mfilename;
    y2j = fullfile(bin,name);
    if ispc
        y2j = y2j + ".exe";
    end
    if exist(y2j,"file") ~= 2
        redAlert("NonexistentTool", ...
            "Could not locate required tool %s", y2j);
    end
    cmd = sprintf("""%s"" < ""%s""", y2j, yamlFile);
    [status, result] = system(cmd);
    if status ~= 0
        error("prodserver:mcp:YAMLParseFailure",...
            "Failed to parse YAML file %s. Reason: %s", ...
            yamlFile, result);
    end
    json = result;
end
