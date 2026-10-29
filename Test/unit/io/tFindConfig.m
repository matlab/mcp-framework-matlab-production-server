classdef tFindConfig < matlab.unittest.TestCase
% Test prodserver.mcp.io.findConfig (choose the serialization format for a
% URI).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function ambiguousFormat(test)
            % Two configurations match both the extension and the type: an
            % ambiguity error that names both of them.
            import prodserver.mcp.io.findConfig
            import prodserver.mcp.io.parseURI

            config = struct('ext',{"csv,txt","csv"}, ...
                'type',{"table","table"}, ...
                'via',{"readtable","readTableAgain"});
            u = parseURI("file:/tmp/data.csv");

            test.verifyError(@()findConfig(config,u,"table"), ...
                "prodserver:mcp:AmbiguousStorageFormat");

            try
                findConfig(config,u,"table");
            catch ex
                test.verifySubstring(ex.message,"readtable");
                test.verifySubstring(ex.message,"readTableAgain");
            end
        end

        function typeResolvesAmbiguity(test)
            % Two configurations match the extension; the type picks one.
            import prodserver.mcp.io.findConfig
            import prodserver.mcp.io.parseURI

            config = struct('ext',{"csv","csv"}, ...
                'type',{"table","matrix"}, ...
                'via',{"readtable","readmatrix"});
            u = parseURI("file:/tmp/data.csv");

            cfg = findConfig(config,u,"table");
            test.verifyEqual(cfg.via,"readtable");
        end

    end

end
