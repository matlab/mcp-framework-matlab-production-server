function answer = preDetectionAnswer(code, data, httpCode, httpMsg)
%preDetectionAnswer Build the struct an Adapter.preDetectionError returns.
%   CODE is the JSON-RPC error code. DATA is the optional `error.data`
%   payload, [] when the revision mandates none. The status defaults to 400,
%   which is what both failures reaching this hook are: they are raised by
%   ProtocolRegistry.resolve, after the request has been attributed but
%   before its stated version was accepted, and no revision answers either
%   one with anything but Bad Request.
%
%   Exists so the struct's field names are written once. Every revision's
%   hook returns the same shape, and handler.internal reads it without
%   knowing which revision produced it -- which is the whole point of the
%   hook.

% Copyright 2026 The MathWorks, Inc.

    arguments
        code
        data = []
        httpCode = 400
        httpMsg = 'Bad Request'
    end

    answer.code = code;
    answer.httpCode = httpCode;
    answer.httpMsg = httpMsg;
    answer.data = data;
end
