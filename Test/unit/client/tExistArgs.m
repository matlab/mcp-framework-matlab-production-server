classdef tExistArgs < matlab.unittest.TestCase
% Argument checks in prodserver.mcp.exist that fail before any request is
% sent, so they need no server. Lists of identifiers against a live (mock)
% server are tested in tClientV20250618 and tClientV20260728.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        endpoint = "http://localhost:9910/noServer/mcp"
    end

    methods (Test)

        function typeSizeMismatchErrors(test)
            test.verifyError(@() prodserver.mcp.exist(test.endpoint, ...
                ["a","b"], ["Tool","Resource","Tool"]), ...
                "prodserver:mcp:SizeMismatch");
        end

        function typeShapeMismatchErrors(test)
        % Same number of elements, different shape.
            test.verifyError(@() prodserver.mcp.exist(test.endpoint, ...
                ["a","b"], ["Tool";"Resource"]), ...
                "prodserver:mcp:SizeMismatch");
        end

        function emptyIdentifierErrors(test)
            test.verifyError(@() prodserver.mcp.exist(test.endpoint, ...
                string.empty, "Tool"), "MATLAB:validators:mustBeNonempty");
        end

    end
end
