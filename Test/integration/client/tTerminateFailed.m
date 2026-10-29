classdef tTerminateFailed < MockCaller
% Ensure that termination errors don't prevent a tools/call from returning
% valid output. Only applies to 2025-06-18, as 2026-07-28 has no notion of a
% session to terminate.
%
% The failure is the mock's. Against this framework's own server a terminate
% cannot fail this way: sessions are minted but not tracked, so the DELETE
% has nothing to end and always succeeds (G12, documented won't-fix). These
% tests exercise the client's handling of a failed terminate, not real session
% termination.

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

            % Clear the protocol adapter cache
            prodserver.mcp.client.Adapter.create(endpoint,action="clearAll");

            % Set the adapter for the 2025-06-18 protocol
            prodserver.mcp.client.Adapter.create(endpoint, protocol="2025-06-18");

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

        function terminateFailureWarnsOnToolError(test)
            % The terminate runs in an onCleanup, so it must also run, and
            % warn, when the call itself fails: the tool error propagates and
            % the warning is emitted on the way out.
            warnId = "prodserver:mcp:TerminateFailed";

            endpoint = startMcpServer(test,"tTerminateFailed.yaml");
            prodserver.mcp.client.Adapter.create(endpoint,action="clearAll");
            prodserver.mcp.client.Adapter.create(endpoint, protocol="2025-06-18");

            test.verifyWarning(@() test.verifyError( ...
                @()prodserver.mcp.call(endpoint,"primeSequence",13,"Gaussian"), ...
                "prodserver:mcp:ToolError"), warnId);
            test.verifyEqual(test.requestCount("DELETE","/mcp"), 1, ...
                "The session must be terminated after a tool error");
                
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

            % Tool error should have sent another DELETE to terminate
            % session.
            test.verifyEqual(test.requestCount("DELETE","/mcp"), 2, ...
                "The session must be terminated after a tool error");

            % warning('query','last') returns the ID of the last warning 
            % setting, regardless of display state, so we can't use it here.
            [w,id] = lastwarn;
            test.verifyTrue(strlength(w) > 0, "Empty warning");

            test.verifyEqual(string(id),warnId, ...
                "Last warning should be " + warnId);
        end
    end

end
