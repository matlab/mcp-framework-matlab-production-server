function schema = classSchema(name, matlabClass, encoding, opts)
%classSchema Schema of a class with no plain JSON type, for an encoding.
%   schema = classSchema(name, matlabClass, encoding) returns the schema of
%   parameter NAME of class MATLABCLASS -- one WireSupport calls Converted
%   or Invertible -- under ENCODING. Under Invertible encoding that is
%   wireTypeSchema's; under JSON, jsonTimeSchema's. It is an error,
%   prodserver:mcp:IncompatibleArgumentType, if the encoding can't carry
%   the class (see mustBeWireType); NAME identifies the parameter, or the
%   part of it, in the message.
%
%   schema = classSchema(..., Name=Value) also takes:
%
%     typemap  The build's typemap.
%     size     The declared size, if any, which shapes the schema.
%     shape    The observed WireShape, for when there is no declared size.
%              Default Either.

% Copyright 2026 The MathWorks, Inc.

    arguments
        name (1,1) string
        matlabClass (1,1) string
        encoding (1,1) prodserver.mcp.WireEncoding
        opts.typemap struct = struct()
        opts.size = []
        opts.shape (1,1) prodserver.mcp.jsonrpc.WireShape = ...
            prodserver.mcp.jsonrpc.WireShape.Either
    end

    prodserver.mcp.validation.mustBeWireType(name, matlabClass, ...
        encoding, opts.typemap);

    if isempty(opts.size)
        shape = opts.shape;
        count = [];
    else
        shape = prodserver.mcp.jsonrpc.WireShape.fromSize(opts.size);
        count = prodserver.mcp.jsonrpc.sizeFromValidation(opts.size);
    end

    if encoding == prodserver.mcp.WireEncoding.Invertible
        schema = prodserver.mcp.jsonrpc.wireTypeSchema(matlabClass, shape);
    else
        schema = prodserver.mcp.jsonrpc.jsonTimeSchema(matlabClass, shape, count);
    end
end
