classdef Level < uint8
%Level Severity of a log line, with MPS's names.
%
%   Trace < Information < Warning < Error. There is no Debug and no None.
%   Warning and Error go to stderr, Trace and Information to stdout.
%
%   See also prodserver.mcp.logging.Log

% Copyright 2026 The MathWorks, Inc.

    enumeration
        Trace       (0)
        Information (1)
        Warning     (2)
        Error       (3)
    end
end
