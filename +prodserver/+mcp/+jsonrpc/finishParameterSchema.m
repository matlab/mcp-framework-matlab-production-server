function d = finishParameterSchema(d, encoding, complete, tag)
%finishParameterSchema The last step in building a parameter's schema.
%   d = finishParameterSchema(d, encoding, complete) gives an externalized
%   parameter (a URL; see isExternalized) its examples of valid URLs, then,
%   under the invertible encoding, marks schema D as invertibly encoded:
%   with the annotation if COMPLETE, when D already describes the whole
%   encoded value (see wireTypeSchema), and otherwise by wrapping it (see
%   wrapInvertible). An externalized parameter is never wrapped: a URL is
%   a plain string. TAG, if given, is the schema of the wrapper's "type"
%   (see wrapperTypeSchema). Both schema paths use this.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    external = prodserver.mcp.jsonrpc.isExternalized(d);
    if external
        d.examples = MCPConstants.ByReferenceExample;
    end
    if encoding == prodserver.mcp.WireEncoding.Invertible
        if complete
            d.annotation = MCPConstants.InvertibleAnnotation;
        elseif ~external
            if nargin < 4
                tag = [];
            end
            d = prodserver.mcp.jsonrpc.wrapInvertible(d, tag);
        end
    end
end
