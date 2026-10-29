function lines = withWireEncodingMsg(lines, io)
%withWireEncodingMsg Add the wire-encoding instruction to a description.
%   lines = withWireEncodingMsg(lines, io) adds the line telling the LLM
%   to encode (IO "input") or decode ("output") the parameter as the
%   wire-encoding resource describes, to the description LINES, a string
%   column. It isn't added to an externalized parameter, which is a URL,
%   or to a description that already names the resource. Both schema paths
%   use this, under the invertible encoding.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    if any(contains(lines, MCPConstants.ByReferencePrefix)) || ...
            any(contains(lines, MCPConstants.WireEncodingResourceURI))
        return
    end
    if strcmpi(io, "input")
        lines = [lines(:); MCPConstants.WireEncodingInputMsg];
    else
        lines = [lines(:); MCPConstants.WireEncodingOutputMsg];
    end
end
