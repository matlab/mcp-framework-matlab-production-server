classdef LogCapture < matlab.unittest.fixtures.Fixture
%LogCapture Capture the archive's log lines for a test.
%
%     captured = test.applyFixture(prodserver.mcp.test.mixin.LogCapture());
%     ... code that logs ...
%     test.verifySubstring(captured.Lines(end), "prodserver:mcp:RequestCancelled");
%
%   Setup drops the archive's Log, so the test starts with a fresh one: no
%   logOnce keys, and no earlier request's context. The fresh Log sends
%   its lines here instead of to stdout and stderr. Teardown drops it
%   again, so no later test inherits the capture. A Log a test makes
%   itself captures through sink(): Log(..., sink=captured.sink()).

% Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = private)
        Lines = strings(0, 1)       % each line, in the order written
        Streams = zeros(0, 1)       % each line's stream: 1 stdout, 2 stderr
    end

    methods
        function fix = LogCapture()
            fix.SetupDescription = "Capture the archive's log lines.";
            fix.TeardownDescription = "Drop the archive's Log.";
        end

        function setup(fix)
            prodserver.mcp.logging.Log.instance(action="clear");
            log = prodserver.mcp.logging.Log.instance();
            log.Sink = fix.sink();
        end

        function teardown(~)
            prodserver.mcp.logging.Log.instance(action="clear");
        end

        function f = sink(fix)
        %sink A Log sink that adds each line to Lines and Streams.
            f = @(stream, line) fix.capture(stream, line);
        end
    end

    methods (Access = private)
        function capture(fix, stream, line)
            fix.Lines(end+1, 1) = line;
            fix.Streams(end+1, 1) = stream;
        end
    end
end
