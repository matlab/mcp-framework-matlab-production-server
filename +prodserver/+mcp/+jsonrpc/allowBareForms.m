function schema = allowBareForms(schema, shape)
%allowBareForms Publish the bare forms a wrapped parameter may take.
%   schema = allowBareForms(schema, shape) turns the generic invertible
%   wrapper SCHEMA (see isGenericWrapper) into an anyOf of the bare values
%   wire_encoding_rules.txt allows -- a number, string, boolean or scalar
%   struct -- and the wrapper itself (see wrapperAlternatives), unless SHAPE,
%   a WireShape, says the parameter is never a scalar. The encoder sends a
%   scalar bare, so a schema without them forbids what the rules tell the
%   LLM to send, and what a tool's scalar outputs are.
%
%   Not oneOf: a scalar struct's bare form and the wrapper are both
%   objects. The description, annotation and other keywords of the wrapper
%   itself (such as x-call-by) stay at the top, where the LLM,
%   externalization and isInvertibleSchema look for them. Any other schema
%   is returned as it is. bareOrWrapped takes the result apart again.

% Copyright 2026 The MathWorks, Inc.

    arguments
        schema
        shape (1,1) prodserver.mcp.jsonrpc.WireShape = ...
            prodserver.mcp.jsonrpc.WireShape.Either
    end

    if shape == prodserver.mcp.jsonrpc.WireShape.Array || ...
            ~prodserver.mcp.jsonrpc.isGenericWrapper(schema)
        return
    end
    [bare, wrapped] = prodserver.mcp.jsonrpc.wrapperAlternatives(schema);
    if isempty(bare)
        return
    end

    % The wrapper is its type, required and properties; everything else
    % describes the parameter.
    own = {'type', 'required', 'properties'};
    wrapped = rmfield(wrapped, setdiff(fieldnames(wrapped), own));
    result = struct('anyOf', {[bare; {wrapped}]});
    for f = setdiff(fieldnames(schema), own, "stable")'
        result.(f{1}) = schema.(f{1});
    end
    schema = result;
end
