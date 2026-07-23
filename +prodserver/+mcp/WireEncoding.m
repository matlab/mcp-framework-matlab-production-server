classdef WireEncoding
% WireEncoding How to encode the data sent between client and server.

% Copyright 2025-2026 The MathWorks, Inc.

    enumeration
        Invertible    % Require x = decode(encode(x))
        JSON          % Allow JSON's ambiguous types
    end
end