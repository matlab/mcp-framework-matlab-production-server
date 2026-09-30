classdef tTerminateFailed < MockCaller

% Copyright 2026 The MathWorks, Inc.

    properties
        exampleFolder
    end

     methods(Test)

        function terminateFailureWarns(test)
            % Negative test: the server fails the terminate (DELETE) request
            % with HTTP 500. prodserver.mcp.call must still return the tool
            % result, emitting prodserver:mcp:TerminateFailed. When the
            % warning is disabled, calling again must produce no warning.
            import matlab.unittest.fixtures.PathFixture

            warnId = "prodserver:mcp:TerminateFailed";

            % primeSequence must be on the path to compute the expected
            % value returned by the (mock) server.
            test.applyFixture(prodserver.mcp.test.mixin.RequireExamples);
            expected = primeSequence(11,"Gaussian");

            % Start the mock server configured to fail termination.
            endpoint = startMcpServer(test,"tTerminateFailed.yaml");

            % First call: terminate fails, so we expect both the prime
            % sequence AND the TerminateFailed warning.
            actual = test.verifyWarning( ...
                @()prodserver.mcp.call(endpoint,"primeSequence",11,"Gaussian"), ...
                warnId);
            test.verifyEqual(actual(:),expected(:), ...
                "Prime sequence returned despite terminate failure.");

            % Second call: disable the warning and confirm none is emitted,
            % while the prime sequence is still returned. Restore the warning
            % state afterwards.
            original = warning("off",warnId);
            test.addTeardown(@()warning(original));

            % Clear lastwarn so we can detect whether a warning fired. A
            % disabled warning does not update lastwarn.
            lastwarn("","");
            actual = prodserver.mcp.call(endpoint,"primeSequence",11,"Gaussian");
            
            % lastwarn returns the ID of the last warning fired, regardless
            % of display state, so we can't use it here.
            w = warning('query','last');

            test.verifyEqual(actual(:),expected(:), ...
                "Prime sequence result with terminate warning disabled.");
            test.verifyEqual(string(w.identifier),warnId, ...
                "Last warning should be " + warnId);
            test.verifyEqual(string(w.state),"off",...
                "Warning state should be 'off'");
        end
    end

end
