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

            % A disabled warning prints nothing, so capture what the call
            % displays. (This used to query warning('query','last'), which
            % reports the state just set above whether or not the call
            % warned at all.)
            output = evalc( ...
                "actual = prodserver.mcp.call(endpoint,""primeSequence"",11,""Gaussian"");");

            test.verifyEqual(actual(:),expected(:), ...
                "Prime sequence result with terminate warning disabled.");
            test.verifyFalse(contains(output,"Failed to terminate"), ...
                "A disabled warning must not be displayed: " + output);
        end

        function terminateRunsOnTheErrorPath(test)
            % The session is terminated from an onCleanup, so it is terminated
            % however prodserver.mcp.call exits. It used to be a statement at
            % the end of the function body, which any error after initialize
            % skipped -- leaking the session, silently, on exactly the calls
            % most likely to be repeated.
            %
            % The fixture answers DELETE with HTTP 500, so the TerminateFailed
            % warning is the evidence that the DELETE was attempted at all.
            % verifyWarning cannot be used here because the call under test
            % must also raise, so lastwarn is the only way to see both.
            endpoint = startMcpServer(test,"tTerminateFailed.yaml");

            % A tool that is not in tools/list. This fails immediately after
            % initialize, well before the tool is ever invoked, so there is a
            % session open and nothing else going on.
            lastwarn("","");   % Clear last warning state
            warnId = "prodserver:mcp:TerminateFailed";
            original = warning("off",warnId);
            test.addTeardown(@()warning(original));

            test.verifyTrue(strlength(lastwarn)==0,"Non empty lastwarn");
            err = MException.empty;
            try
                prodserver.mcp.call(endpoint,"noSuchTool",1);
            catch err
            end

            test.assertNotEmpty(err,"Calling an unlisted tool must fail");
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:NonUniqueTool",err.message);

            % warning('query','last') returns the ID of the last warning
            % setting, regardless of display state, so we can't use it here.
            [w,id] = lastwarn;
            test.verifyTrue(strlength(w) > 0, "Empty warning");

            test.verifyEqual(string(id),warnId, ...
                "Last warning should be " + warnId);
        end
    end

end
