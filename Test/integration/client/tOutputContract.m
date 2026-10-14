classdef tOutputContract < MockCaller
% Outputs of prodserver.mcp.call are positional, and surplus ones are dropped.
%
% The client used to try to append the tool's undeclared outputs to varargout as
% name/value pairs. It never worked -- the guard it was behind compared an input
% count against numel() of a scalar struct, so it only ran for a tool called with
% no inputs, and when it did run its cellfun threw on anything but a uniform
% result. It also could not have worked: MATLAB discards varargout entries past
% nargout, so there was nowhere for the surplus to go.
%
% So the contract is positional, ordered by the output schema and then by the
% signature, and a tool returning more than was asked for is not an error. That
% is a contract worth pinning, because "the surplus is silently dropped" and "the
% surplus was supposed to come back and the code to do it was deleted" look
% identical from the outside.
%
% The three refusals below are the cases that previously surfaced as MATLAB
% indexing errors naming a field, with nothing to say which tool, which endpoint,
% or what the caller should do instead.

% Copyright 2026 The MathWorks, Inc.

    methods(Test)

        function positionalOutputIgnoresSurplus(test)
        % The declared output comes back whether or not the server also sent
        % undeclared ones.
            endpoint = startMcpServer(test,"tOutputContract.yaml");
            expected = 'one declared output';

            plain = prodserver.mcp.call(endpoint,"mockOneOutput",2001,"Plain");
            test.verifyEqual(plain,expected, ...
                "The one declared output, with nothing else sent");

            surplus = prodserver.mcp.call(endpoint,"mockOneOutput", ...
                2003,"Surplus");
            test.verifyEqual(surplus,expected, ...
                "The declared output, with two undeclared ones alongside it");
        end

        function statementCallReturnsAns(test)
        % A call made as a statement has nargout 0. Filling only 1:nargout left
        % it returning nothing at all -- no display and no ans -- which is
        % indistinguishable from a tool that produced no result.
            endpoint = startMcpServer(test,"tOutputContract.yaml");

            clear ans
            prodserver.mcp.call(endpoint,"mockOneOutput",2001,"Plain");

            test.assertEqual(exist("ans","var"),1, ...
                "A statement-level call must leave its result in ans");
            test.verifyEqual(ans,'one declared output'); %#ok<NOANS>
        end

        function tooManyOutputsIsRefused(test)
        % Asking for more outputs than the tool declares used to index past the
        % end of the name list and raise MATLAB:badsubscript.
            endpoint = startMcpServer(test,"tOutputContract.yaml");

            err = captureError( ...
                @()prodserver.mcp.call(endpoint,"mockOneOutput",2001,"Plain"),2);

            test.assertNotEmpty(err, ...
                "Requesting 2 outputs from a 1-output tool must fail");
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:TooFewOutputs",err.message);
            test.verifyTrue(contains(err.message,"mockOneOutput"), ...
                "The diagnosis must name the tool: " + err.message);
            test.verifyTrue(contains(err.message,"report"), ...
                "The diagnosis must name what the tool does declare: " + ...
                err.message);
        end

        function undeclaredOutputsAreRefused(test)
        % Tools that declare no outputs at all. There is no order to return
        % their structured content in, so asking for an output is refused --
        % but asking for nothing is not, since nothing is what the tool
        % promised.
        %
        % Both shapes of "no outputs" are covered. mockEmptyOutputs sends an
        % output member naming nothing, which is what this framework's server
        % emits; mockNoOutputs omits the member entirely, which used to crash
        % in internal/signature.m before reaching any of this.
            endpoint = startMcpServer(test,"tOutputContract.yaml");

            for tool = ["mockNoOutputs","mockEmptyOutputs"]
                err = captureError( ...
                    @()prodserver.mcp.call(endpoint,tool,7,"Whatever"),1);

                test.assertNotEmpty(err,"Requesting an output from " + ...
                    tool + ", which has none, must fail");
                test.verifyEqual(string(err.identifier), ...
                    "prodserver:mcp:TooFewOutputs",err.message);

                % Before this change the error above was unreachable for the
                % case its message described, and it reported the received
                % count as numel(req) -- always 0 in the branch it sat in.
                test.verifyWarningFree( ...
                    @()prodserver.mcp.call(endpoint,tool,7,"Whatever"), ...
                    "Requesting no outputs from " + tool + ", which has " + ...
                    "none, must be quiet");
            end
        end

        function missingDeclaredOutputIsRefused(test)
        % The names are a union of two sources, either of which may name
        % something the server did not send. That used to surface as
        % MATLAB:nonExistentField from deep inside the client.
            endpoint = startMcpServer(test,"tOutputContract.yaml");

            err = captureError( ...
                @()prodserver.mcp.call(endpoint,"mockOneOutput",2002,"Missing"),1);

            test.assertNotEmpty(err, ...
                "A declared output the server did not send must fail");
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:MissingOutputs",err.message);
            test.verifyTrue(contains(err.message,"report"), ...
                "The diagnosis must name the output that is absent: " + ...
                err.message);
        end
    end

end

function err = captureError(fcn,n)
%captureError Invoke FCN asking for N outputs; return the MException it raised.
%   Empty if it raised none. nargout is part of the contract under test, and an
%   anonymous handle invoked by verifyError is called with nargout 0, so the
%   count has to be set here rather than left to the framework.

    err = MException.empty;
    out = cell(1,n);
    try
        [out{1:n}] = fcn(); %#ok<NASGU> the outputs are not what is under test
    catch err
    end
end
