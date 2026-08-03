function [pth,val] = nestedFieldValues(s,f)
% Recursively extract all field values and their full paths from field F of
% structure S. Both pth and val are cell arrays.

% Copyright 2026 The MathWorks, Inc.

    if isstruct(s.(f))
        fields = string(fieldnames(s.(f)))';
        val = {};
        pth = {};
        for sf = fields
            [sp,v] = prodserver.mcp.internal.nestedFieldValues(s.(f),sf);
            for p = 1:numel(sp)
                sp{p} = [ {f}, sp{p} ]; 
            end
            pth = [ pth, sp ]; %#ok<AGROW>
            val = [ val, v ];  %#ok<AGROW>
        end
    else
        pth = { { f } } ;
        val = { s.(f) };
    end
end

