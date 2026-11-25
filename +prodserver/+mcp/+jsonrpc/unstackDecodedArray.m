function members = unstackDecodedArray(value)
%unstackDecodedArray The elements of a JSON array that jsondecode stacked.
%   members = unstackDecodedArray(value) returns, as a column cell array,
%   the elements of the JSON array that jsondecode decoded as VALUE.
%
%   jsondecode stacks the elements of a JSON array along the first
%   dimension when it can: numbers or booleans into a column, arrays of
%   the same size into the rows of a matrix (or the slices of a higher-
%   dimensional array), objects with the same fields into a struct array.
%   Element k is then VALUE(k,:,...), which is returned in the shape
%   jsondecode gives that element alone: a row of a matrix as a column, a
%   slice of a 3-D array as a matrix. A one-element array decodes as its
%   element, so a scalar, or a row (from [[a, b, ...]]), is one element.
%
%   A cell array is returned as it is, as a column: jsondecode gives a
%   JSON array whose elements it can't stack as a cell, one element per
%   cell, and MATLAB code builds lists as cells. A string array has one
%   element per string.
%
%   JSON Schema's enum and examples keywords are arrays. Unstacking their
%   values gives each member its own cell, which jsonencode always writes
%   as a JSON array, even with one member.

% Copyright 2026 The MathWorks, Inc.

    if iscell(value)
        members = value(:);
    elseif ischar(value)
        % jsondecode gives a JSON string as char: one element.
        members = {value};
    elseif isstring(value)
        members = num2cell(value(:));
    elseif isempty(value)
        members = cell(0, 1);
    elseif isrow(value)
        % A scalar, or the one row of [[a, b, ...]]: one element.
        members = {value};
    else
        % Element k is the slice VALUE(k,:,...). Linear indexing of the
        % other dimensions keeps their order, so reshape restores them.
        sz = size(value);
        members = cell(sz(1), 1);
        for k = 1:sz(1)
            members{k} = reshape(value(k, :), [sz(2:end) 1]);
        end
    end
end
