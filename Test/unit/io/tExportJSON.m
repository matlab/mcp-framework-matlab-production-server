classdef tExportJSON < matlab.unittest.TestCase
% Test prodserver.mcp.io.exportJSON (serialize a value for a json: URI).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tScalarFromTextURI(test)
            import prodserver.mcp.io.exportJSON
            import prodserver.mcp.io.fromJSON
            json = exportJSON("json:x", 5);
            test.verifyEqual(fromJSON(json), 5);
        end

        function tVectorFromTextURI(test)
            import prodserver.mcp.io.exportJSON
            import prodserver.mcp.io.fromJSON
            json = exportJSON("json:v", [1 2 3]);
            test.verifyEqual(fromJSON(json), [1 2 3]);
        end

        function tStructURIInput(test)
            % A pre-parsed URI struct is accepted directly.
            import prodserver.mcp.io.exportJSON
            import prodserver.mcp.io.parseURI
            import prodserver.mcp.io.fromJSON
            u = parseURI("json:v");
            test.verifyEqual(fromJSON(exportJSON(u, 7)), 7);
        end

        function tBadVariableNameErrors(test)
            import prodserver.mcp.io.exportJSON
            test.verifyError(@() exportJSON("json:not a name", 5), ...
                "prodserver:mcp:BadVariableName");
        end

        function tWrongSchemeErrors(test)
            import prodserver.mcp.io.exportJSON
            test.verifyError(@() exportJSON("file:x", 5), ...
                "prodserver:mcp:UnexpectedScheme");
        end

    end

end
