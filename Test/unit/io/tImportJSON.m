classdef tImportJSON < matlab.unittest.TestCase
% Test prodserver.mcp.io.importJSON (decode a json: URI into a MATLAB value).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tScalarFromURI(test)
            % The JSON payload lives in the URI query string.
            import prodserver.mcp.io.importJSON
            import prodserver.mcp.io.toJSON
            test.verifyEqual(importJSON("json:x?" + toJSON(42, "Native")), 42);
        end

        function tRoundTripWithExportJSON(test)
            % importJSON(exportJSON(value)) semantics via a json: URI.
            import prodserver.mcp.io.importJSON
            import prodserver.mcp.io.toJSON
            value = [1 2 3];
            uri = "json:v?" + toJSON(value, "Native");
            test.verifyEqual(importJSON(uri), [1;2;3]);
        end

        function tStructURIInput(test)
            % A pre-parsed URI struct (with scheme/path/query) is accepted.
            import prodserver.mcp.io.importJSON
            import prodserver.mcp.io.parseURI
            import prodserver.mcp.io.toJSON
            u = parseURI("json:x?" + toJSON(9, "Native"));
            test.verifyEqual(importJSON(u), 9);
        end

    end

end
