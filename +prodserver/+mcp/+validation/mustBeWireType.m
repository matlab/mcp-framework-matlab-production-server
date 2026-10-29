function mustBeWireType(name, matlabClass, encoding, typemap)
%mustBeWireType Error unless the wire encoding can carry the parameter.
%   mustBeWireType(name, matlabClass, encoding, typemap) errors if no wire
%   encoding can carry values of matlabClass, or if only the invertible
%   encoding can and encoding is not Invertible. name identifies the
%   parameter, or the part of it, in the message.

% Copyright 2026 The MathWorks, Inc.

    arguments
        name (1,1) string
        matlabClass (1,1) string
        encoding (1,1) prodserver.mcp.WireEncoding
        typemap struct = struct()
    end

    import prodserver.mcp.jsonrpc.WireSupport

    support = WireSupport.of(matlabClass, typemap);
    if support == WireSupport.None
        throwAsCaller(MException("prodserver:mcp:IncompatibleArgumentType", ...
            "Parameter '%s' has unsupported MATLAB type '%s'. No wire " + ...
            "encoding can carry it. Valid types include %s.", ...
            name, matlabClass, WireSupport.supportedClasses()));
    elseif support == WireSupport.Invertible && ...
            encoding ~= prodserver.mcp.WireEncoding.Invertible
        throwAsCaller(MException("prodserver:mcp:IncompatibleArgumentType", ...
            "Parameter '%s' has MATLAB type '%s', which only the " + ...
            "invertible wire encoding can carry. Build with " + ...
            "encoding=""Invertible"".", name, matlabClass));
    end
end
