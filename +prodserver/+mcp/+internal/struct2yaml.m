function yaml = struct2yaml(data,indent)
%struct2yaml Convert a structure to a YAML string. 
%
%   YAML = struct2yaml(DATA, INDENT) converts the structure DATA into a
%   YAML string. Each line in YAML starts with at least INDENT spaces. 
%   INDENT defaults to 0 and increases by 2 for every level of nested data.
%   
%Given a structure S, the roundtrip struct2yaml -> yaml2json -> jsondecode 
%produces an NS equivalent to S; the differences likely include field
%order (NS will have all fields in alphabetical order) and conversion 
%between strings and character arrays.
% 
%Also, don't expect MATLAB class instances (other than string) to survive
%the roundtrip -- in general class instances become structures containing
%the public fields of the object.
%
%Example:
%
%    Save scheme marshalling configuration to /marshal/config/scheme.yaml:
%
%        yaml = struct2yaml(config);
%        writelines(yaml, "/marshal/config/scheme.yaml");
%
%See also: yaml2json, jsondecode

% Copyright (c) 2024, The MathWorks, Inc.

    import prodserver.mcp.internal.struct2yaml
    if nargin == 1
        indent = 0;
    end
    S = 2;

    if isstruct(data)
        fields = string(fieldnames(data));
        yaml = "";
        N = numel(data);
        prefix = newline + string(blanks(indent));
        arrayPrefix = newline + string(blanks(indent)) + "- ";
        for n = 1:N
            for f = 1:numel(fields)
                if N > 1
                    if f == 1
                        yaml = yaml + arrayPrefix;
                    else
                        yaml = yaml + prefix + string(blanks(S));
                    end
                else
                    yaml = yaml + prefix;
                end
                yaml = yaml + fields(f) + ": " + ...
                   struct2yaml(data(n).(fields(f)),indent+S+(S*(N>1)));
            end
        end
    else
        yaml = jsonencode(data);
    end
    if indent == 0
        yaml = strtrim(yaml);
    end
end
