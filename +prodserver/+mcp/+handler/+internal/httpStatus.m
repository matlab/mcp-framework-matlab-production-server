function [code, reason] = httpStatus(code)
%httpStatus An HTTP status code and its reason phrase.
%   [code, reason] = httpStatus(code) returns CODE and the standard reason
%   phrase for it, as a character vector: 200 'OK', 400 'Bad Request', 404
%   'Not Found', 500 'Internal Server Error', and the others the server
%   sends. It is an error, prodserver:mcp:UnknownHTTPStatus, for a code
%   the server doesn't send.

% Copyright 2026 The MathWorks, Inc.

    switch code
        case 200, reason = 'OK';
        case 202, reason = 'Accepted';
        case 204, reason = 'No Content';
        case 400, reason = 'Bad Request';
        case 404, reason = 'Not Found';
        case 405, reason = 'Method Not Allowed';
        case 406, reason = 'Not Acceptable';
        case 415, reason = 'Unsupported Media Type';
        case 500, reason = 'Internal Server Error';
        otherwise
            error("prodserver:mcp:UnknownHTTPStatus", ...
                "No reason phrase for HTTP status %d.", code);
    end
end
