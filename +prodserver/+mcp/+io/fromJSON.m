function value = fromJSON(json,encoder)
%fromJSON Create a MATLAB value from a JSON representation of it.
%
%    VALUE = fromJSON(JSON) creates VALUE from a JSON string. JSON may be
%    in MATLAB Production Server JSON format or "native" JSON format. 
%
% Example:
% 
%   Convert a 3x3 Hilbert matrix to JSON and back again.
%
%     fromJSON(toJSON(hilb(3)))
%
%     1.0000    0.5000    0.3333
%     0.5000    0.3333    0.2500
%     0.3333    0.2500    0.2000
%
% See also: toJSON

% Copyright 2024, The MathWorks, Inc.

    import prodserver.mcp.io.fromJSON

    useMPS = any(contains(json,"""mwdata"""));
    if nargin == 1
        if useMPS
            encoder = "MPS";
        else
            encoder = "Native";
        end
    end

    hasMPS = contains(which("mps.json.decode"),"built-in");
    if useMPS
        if hasMPS && strcmpi(encoder,"EmulateMPS") == false
            value = mps.json.decode(json);
        else
            data = jsondecode(json);
            value = reconStruct(data);
        end
    else
        value = jsondecode(json);
    end
end

function value = reconStruct(data)   
%reconStruct Build a MATLAB value from the structure created by decoding an
%MPS-style JSON encoding: each "data" field is either a JSON value or a
%struct with fields mwdata, mwtype, mwsize.

    import prodserver.mcp.internal.hasField

    if any(hasField(data,["mwdata","mwsize","mwtype"])) == false 
        if isstruct(data)
            fields = fieldnames(data)';
            null = arrayfun(@(~)cell(1,numel(data)),1:numel(fields),...
                UniformOutput=false);
            args = [ fields; null ];
            value = struct(args{:});
            for n = 1:numel(data)
                for f = 1:numel(fields)
                    value(n).(fields{f}) = reconStruct(data(n).(fields{f}));
                end
            end
        elseif iscell(data)
            value = cellfun(@reconStruct,data,UniformOutput=false);
        else
            value = data;
        end
        return;
    end
    sz = data.mwsize;
    if iscolumn(sz), sz = sz'; end
    
    if strcmpi(data.mwtype,"cell")
        value = cell(sz);
        for n = 1:numel(value)
            if iscell(data.mwdata)
                v = data.mwdata{n};
            else
                v = data.mwdata(n);
            end
            value{n} = reconStruct(v);
        end
    elseif strcmpi(data.mwtype,"struct")
        fields = fieldnames(data.mwdata)';
        val = cell(1,numel(fields));
        scalarStruct = prod(sz) == 1;
        for n = 1:numel(fields)
            val{n} = reconStruct(data.mwdata.(fields{n}));
            if scalarStruct
                val{n} = { val{n} };
            else
                val{n} = num2cell(val{n});
            end
        end
        args = [fields; val];
        value = struct(args{:});
    else
        value = data.mwdata;
        if strcmpi(class(value),data.mwtype) == false
            value = feval(data.mwtype,value);
        end
    end

    if isequal(size(value),sz) == false
        value = reshape(value(:),sz);
    end
    
end
    