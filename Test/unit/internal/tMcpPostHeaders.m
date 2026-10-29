classdef tMcpPostHeaders < matlab.unittest.TestCase
% The client's Accept header (G15), and the server's reading of one (XD22).
%
% G15 is the one defect on the client's request side, so no server test can
% catch it: the server accepts a request with no Accept at all. These tests
% assert on the headers the client builds.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function postHeadersCarryAccept(test)
            h = prodserver.mcp.internal.mcpPostHeaders();
            test.verifyEqual(string([h.Name]), ["Content-Type", "Accept"]);
            accept = lower(strtrim(split(string(h(2).Value), ",")));
            test.verifyTrue(all(ismember( ...
                ["application/json", "text/event-stream"], accept)), ...
                "Both specs: Accept MUST list both types");
        end

        function postHeadersAreAcceptedByTheServer(test)
            % The client's Accept must pass the server's own 406 gate.
            h = prodserver.mcp.internal.mcpPostHeaders();
            test.verifyTrue(prodserver.mcp.internal.acceptsJson( ...
                {char(h(2).Name), char(h(2).Value)}));
        end

        function protocolHeadersStayWithoutAccept(test)
            % Deliberately not added there: its one production caller
            % POSTs text/plain to the non-MCP signature handler.
            for c = {prodserver.mcp.client.v20250618.Adapter("http://h:1/a/mcp"), ...
                     prodserver.mcp.client.v20260728.Adapter("http://h:1/a/mcp")}
                h = c{1}.protocolHeaders();
                test.verifyFalse(any(strcmpi(string([h.Name]), "Accept")));
            end
        end

        function acceptsJsonReadsRanges(test)
            yes = {cell(0,2), {'Accept','*/*'}, {'Accept','application/*'}, ...
                {'accept','text/event-stream, application/json;q=0.5'}, ...
                {'Other','x'}, {}};
            no = {{'Accept','text/event-stream'}, {'Accept','text/html, image/*'}, ...
                {'Accept','application/jsonp'}, {'Accept',''}};
            for k = 1:numel(yes)
                test.verifyTrue(prodserver.mcp.internal.acceptsJson(yes{k}), ...
                    "Expected acceptable: " + k);
            end
            for k = 1:numel(no)
                test.verifyFalse(prodserver.mcp.internal.acceptsJson(no{k}), ...
                    "Expected not acceptable: " + k);
            end
        end

        function acceptsJsonNeverThrowsOnMalformedHeaders(test)
            for h = {{'Accept'}, {1, 2}, {'Accept', 7}, 'Accept: */*', []}
                test.verifyTrue(prodserver.mcp.internal.acceptsJson(h{1}));
            end
        end

    end
end
