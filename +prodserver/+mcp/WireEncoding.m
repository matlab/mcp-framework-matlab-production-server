classdef WireEncoding
% WireEncoding How to encode the data sent between client and server.

    enumeration
        Invertible    % Require x = decode(encode(x))
        JSON          % Allow JSON's ambiguous types
    end
end