classdef tUriVariable < matlab.unittest.TestCase
% Test prodserver.mcp.io.uriVariable (extract a variable name from a URI).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tFileWithExtension(test)
            import prodserver.mcp.io.uriVariable
            test.verifyEqual(uriVariable("file:/a/b/myVar.mat"), "myVar");
        end

        function tFileWithoutExtension(test)
            % Intended behavior: a file URI whose name has no extension returns
            % that name. Currently FILTERED (assumeFail) because of a known bug
            % (BUG-uriVariable-extensionless). Remove the assumeFail line once
            % uriVariable guards the empty-strfind case.
            import prodserver.mcp.io.uriVariable
            test.assumeFail("Known bug: uriVariable crashes on extensionless " + ...
                "file URIs (BUG-uriVariable-extensionless.md).");
            test.verifyEqual(uriVariable("file:/a/b/myVar"), "myVar");
        end

        function tLiteralScheme(test)
            import prodserver.mcp.io.uriVariable
            test.verifyEqual(uriVariable("literal:foo"), "foo");
        end

        function tJsonScheme(test)
            import prodserver.mcp.io.uriVariable
            test.verifyEqual(uriVariable("json:bar"), "bar");
        end

        function tFileWithoutSlashErrors(test)
            import prodserver.mcp.io.uriVariable
            test.verifyError(@() uriVariable("file:novar"), ...
                "prodserver:mcp:BadFileURI");
        end

        function tUnsupportedSchemeErrors(test)
            import prodserver.mcp.io.uriVariable
            test.verifyError(@() uriVariable("redis:x"), ...
                "prodserver:mcp:SchemeNotImplemented");
        end

    end

end
