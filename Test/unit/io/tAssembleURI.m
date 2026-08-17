classdef tAssembleURI < matlab.unittest.TestCase
% Test prodserver.mcp.io.assembleURI (rebuild a URI string from parsed parts).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tFileRoundTrip(test)
            import prodserver.mcp.io.parseURI
            import prodserver.mcp.io.assembleURI
            test.verifyEqual(assembleURI(parseURI("file:/a/b.mat")), "file:/a/b.mat");
        end

        function tAuthorityWithPort(test)
            import prodserver.mcp.io.parseURI
            import prodserver.mcp.io.assembleURI
            test.verifyEqual(assembleURI(parseURI("http://host:8080/p")), ...
                "http://host:8080/p");
        end

        function tSchemeLowercased(test)
            % Schemes are case-insensitive and emitted lower-case.
            import prodserver.mcp.io.parseURI
            import prodserver.mcp.io.assembleURI
            test.verifyEqual(assembleURI(parseURI("HTTP://h/p")), "http://h/p");
        end

        function tQueryPreserved(test)
            import prodserver.mcp.io.parseURI
            import prodserver.mcp.io.assembleURI
            test.verifyEqual(assembleURI(parseURI("http://h/p?a=1&b=2")), ...
                "http://h/p?a=1&b=2");
        end

        function tVectorInput(test)
            % assembleURI operates elementwise over a struct array.
            import prodserver.mcp.io.parseURI
            import prodserver.mcp.io.assembleURI
            uris = ["file:/a.mat", "http://h/p"];
            parsed = arrayfun(@parseURI, uris);
            test.verifyEqual(assembleURI(parsed), uris);
        end

    end

end
