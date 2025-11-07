function json = toJSON(value,format)
%toJSON Convert a MATLAB value to a JSON string.
%
%   JSON = toJSON(VALUE) converts VALUE to a JSON string. By default the
%   JSON string follows MATLAB Production Server's JSON format.
%
%   JSON = toJSON(...,"Native") forces the JSON string into native JSON
%   format. Note: this may cause some values to decode into types that do
%   not match their originals. String arrays, in particular, will decode
%   into cell arrays of character vectors.
%
% Example:
% 
%   Convert a Pascal matrix of order 4 to JSON and back again.
%
%     fromJSON(toJSON(pascal(4)))
%
%     1     1     1     1
%     1     2     3     4
%     1     3     6    10
%     1     4    10    20
%
% See also: fromJSON

% Copyright 2024, The MathWorks, Inc.

    import prodserver.mcp.io.toJSON

    function v = encodeArray(v,sz)
        v = jsonencode([v(:)]);
        if prod(sz) == 1
            v = "[" + v + "]";
        end
    end

    nativeJSON = false;
    if nargin == 1
        format = "";
    elseif nargin > 1 && strcmpi(format,"Native")
        nativeJSON = true;
    end

    if nativeJSON
        json = jsonencode(value);
    else
        emulateMPS = true;  % When would you not want this?
        useMPS = startsWith(which("_mpsjsonencode"),"built-in");
        if useMPS && strcmpi(format,"EmulateMPS") == false
            json = builtin("_mpsjsonencode", value, 'small', 'string', false);
        elseif emulateMPS
            if iscell(value) 
                value = cellfun(@(v)prodserver.mcp.io.toJSON(v,format), ...
                    value,UniformOutput=false);
                json = sprintf('{"mwdata":[%s],"mwtype":"cell","mwsize":[%s]}', ...
                    strjoin(value,","),strjoin(string(size(value)),","));
            elseif isstruct(value)
                % Create a JSON structure where each field is an array of
                % the values of the corresponding field in the input 
                % structure array.
                %
                %  e: [ {mwdata: 5, mwsize:[1,1], mwtype: double}, ... ]
                fields = fieldnames(value);
                val = cell(1,numel(fields));
                for n = 1:numel(fields)
                    v = [value.(fields{n})];
                    if isscalar(value) == false
                        v = encodeArray(v, size(v));
                    else
                        v = "[" + toJSON(v,format) + "]";
                    end
                    % v = toJSON(v,format);
                    val{n} = sprintf('"%s":%s',fields{n},v);
                end
                json = sprintf('{"mwdata":{%s},"mwtype":"struct","mwsize":[%s]}', ...
                    strjoin(val,","),strjoin(string(size(value)),","));
            else
                % Capture original type and size because char changes both
                % below.
                type = class(value);
                sz = size(value);
                % Must quote strings
                if isstring(value)
                    value = arrayfun(@(s)"""" + s + """",value);
                    value = sprintf("[%s]",strjoin(value,","));
                elseif ischar(value)
                    value = "[""" + string(value) + """]";
                elseif isnumeric(value)
                    value = encodeArray(value,sz);
                end
                json = sprintf('{"mwdata":%s,"mwsize":[%s],"mwtype":"%s"}', ...
                    value, strjoin(string(sz),","), type);
            end
        else
        end
    end

end