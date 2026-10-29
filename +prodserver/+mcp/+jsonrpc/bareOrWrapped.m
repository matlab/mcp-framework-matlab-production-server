function [tf, bare, wrapped] = bareOrWrapped(schema)
%bareOrWrapped Take apart a schema of allowBareForms'.
%   [tf, bare, wrapped] = bareOrWrapped(schema) is true if SCHEMA is an
%   anyOf whose last alternative is the generic invertible wrapper (see
%   isGenericWrapper), as allowBareForms writes, and then returns the bare
%   alternatives, as a cell column, and the wrapper. Otherwise tf is false
%   and bare and wrapped are empty.

% Copyright 2026 The MathWorks, Inc.

    tf = false;
    bare = {};
    wrapped = [];
    alts = prodserver.mcp.jsonrpc.schemaAlternatives(schema);
    if numel(alts) >= 2 && prodserver.mcp.jsonrpc.isGenericWrapper(alts{end})
        tf = true;
        bare = alts(1:end-1);
        wrapped = alts{end};
    end
end
