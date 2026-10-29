function verifyConformantResponse(test, response)
%verifyConformantResponse Assert the transport-level invariants of a response.
%   verifyConformantResponse(TEST, RESPONSE) checks the parts of an
%   mcpHandler RESPONSE that every response must get right, whatever the
%   request, revision or outcome:
%
%     - every header name and value is char (Production Server requires it);
%     - no header name appears twice, compared case-insensitively;
%     - at most one Mcp-Session-Id;
%     - no handler-set Content-Length (Production Server frames the body
%       itself, so a second one goes out on the wire -- XD17);
%     - Content-Type if and only if there is a body;
%     - 202 and 204 carry no body;
%     - a JSON body is a JSON-RPC 2.0 message with exactly one of result
%       and error.
%
%   A package function rather than a MCPHandlerBase method, because the
%   suites that build their envelopes by hand (tVersionResolution,
%   tHandlerV20260728) deliberately do not inherit that base.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.protocol.v20250618.Constants

    headers = response.Headers;
    test.assertTrue(iscell(headers) && (isempty(headers) || size(headers,2) == 2), ...
        "Headers must be an Nx2 cell array");

    for k = 1:size(headers,1)
        test.verifyTrue(ischar(headers{k,1}), ...
            sprintf("Header name in row %d is a %s, not char", ...
            k, class(headers{k,1})));
        test.verifyTrue(ischar(headers{k,2}), ...
            sprintf("Value of header '%s' is a %s, not char", ...
            string(headers{k,1}), class(headers{k,2})));
    end

    names = lower(string(headers(:,1)));
    [u, ~, j] = unique(names);
    dup = u(accumarray(j(:), 1) > 1);
    if ~isempty(dup)
        test.verifyFail("Repeated header name(s): " + join(dup, ", "));
    end

    test.verifyLessThanOrEqual(nnz(names == lower(Constants.SessionId)), 1, ...
        "At most one Mcp-Session-Id may be sent");

    test.verifyFalse(any(names == lower(MCPConstants.ContentLength)), ...
        "The handler must not set Content-Length; Production Server does");

    hasBody = ~isempty(response.Body);
    hasType = any(names == lower(MCPConstants.ContentType));
    test.verifyEqual(hasType, hasBody, ...
        "Content-Type must be present if and only if there is a body");

    if any(response.HttpCode == [202 204])
        test.verifyFalse(hasBody, sprintf("HTTP %d must carry no body", ...
            response.HttpCode));
    end

    if hasBody && hasType
        ct = string(headers{find(names == lower(MCPConstants.ContentType),1),2});
        if startsWith(lower(ct), prodserver.mcp.internal.Constants.MIMETypeJSON)
            msg = jsondecode(native2unicode(response.Body, "UTF-8"));
            test.verifyTrue(isstruct(msg) && isscalar(msg), ...
                "A JSON body must be a single JSON-RPC message");
            if isstruct(msg) && isscalar(msg)
                % A literal, not MCPConstants.jrpcVersion: this is an oracle,
                % and an oracle that read the constant would agree with the
                % code under test however wrong the constant became (§6.2
                % of the conformance plan).
                test.verifyTrue(isfield(msg, "jsonrpc") && ...
                    isequal(string(msg.jsonrpc), "2.0"), ...
                    'A JSON-RPC message must carry "jsonrpc":"2.0"');
                test.verifyTrue(xor(isfield(msg, "result"), isfield(msg, "error")), ...
                    "A JSON-RPC response carries exactly one of result and error");
            end
        end
    end
end
