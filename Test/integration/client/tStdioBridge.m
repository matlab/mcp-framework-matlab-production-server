classdef tStdioBridge < MockCaller
% Run the STDIO bridge's own tests, Test/python/test_mcpstdio2http.py, with
% the Python interpreter MockCaller finds (MCP_TEST_PYTHON_PATH, or py or
% python3). They use a fake requests module, so they need only the standard
% library and no server.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function bridgeTests(test)
            folder = fullfile(fileparts(mfilename("fullpath")), "..", "..", "python");
            % -B: no __pycache__ folder beside the bridge.
            cmd = sprintf('%s -B -m unittest discover -s "%s" -p "test_*.py" -v', ...
                test.python, folder);
            [status, output] = system(cmd);
            test.verifyEqual(status, 0, string(output));
            test.verifyTrue(contains(output, "OK"), string(output));
        end

    end
end
