function tf = hasField(s, index)
%hasField Does the structure have a field reachable by the string index?
%
%    tf = hasField(s, index) returns true only if INDEX names either a
%    top-level or nested field of structure S.
%
% INDEX must be one or more strings consisting of of a single field name 
% or a series of field names separated by dots. INDEX may be string array
% or a character vector.
%
% Also works on properties of objects.
%
% Example:
%
%   >> car.wheel.diameter = 16;
%
%   >> tf = hasField(car, "wheel.diameter")
%      tf = 
%         true
%
%   >> tf = hasField(car, 'wheel')
%      tf = 
%         true
%
%   >> tf = hasField(car, "wing")
%      tf = 
%         false
%
%   >> tf = hasField(car, 'wing.elevator')
%      tf = 
%         false
%
%   >> tf = hasField(car, 23)
%   Error

% Copyright 2025, The MathWorks, Inc.

    

    if ischar(index), index = string(index); end
    if ~isstring(index)
        error("prodserver:mcp:BadFieldNameType", ...
"Invalid structure field type %s. Names must be string array, " + ...
"character vector, or cell array of character vectors.",class(index));
    end
        
    % Prove it!
    tf = false(1,numel(index));

    for n = 1:numel(index)
        ss = s;  % Reference to structure we're "exploring"
        pth = split(index(n),".");
        if iscell(pth)
            pth = string(pth);
        end
        
        % While more path segments that are fields
        while tf(n) == false && ~isempty(pth) && isDotRef(ss, pth(1))
            % Have we come to the end of the path?
            if isscalar(pth)
                tf(n) = true;
            else
                % Into the the depths.
                ss = ss.(pth(1));
                pth = pth(2:end);
            end
        end
    end
end

function tf = isDotRef(thing, field)
%isDotRef Does <thing>.<field> have any meaning?
    tf = false;
    if isstruct(thing)
        tf = isfield(thing,field);
    elseif isobject(thing)
        tf = isprop(thing,field);
    end
    % thing may be N-dimensional. Flatten tf into a vector and look for any
    % non-zero value. isDotRef MUST return a scalar boolean.
    tf = any([tf(:)]);
end