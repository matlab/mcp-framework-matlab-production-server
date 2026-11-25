classdef tSignature < prodserver.mcp.test.base.MCPHandlerBase
% Test signature handler

% Copyright 2025-2026 The MathWorks, Inc.

    properties (ClassSetupParameter)
        encoding = { prodserver.mcp.WireEncoding.JSON, ...
            prodserver.mcp.WireEncoding.Invertible };
    end

    methods (TestClassSetup)
        
        function useExamples(test)
            % Add examples to the path
            test.applyFixture(prodserver.mcp.test.mixin.RequireExamples());
        end

        function prepareTools(test,encoding)
            % Assume defineForMCP is working. It has its own tests. :-)
            % Better decoupling requires a lot of (probably unnecessary)
            % work.
            test.fcnNames = ["plotTrajectoriesMCP","primeSequence"];
            test.toolNames = ["plotTrajectories","primeSequence"];
    
            defineTools(test,test.fcnNames,test.toolNames,encoding=encoding);
        end
    end

    methods (Test)

        function options(test)
            import prodserver.mcp.MCPConstants

            % Get base request structure
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, 'text/plain'}];
            req.Method = 'OPTIONS';
            req.Headers = [req.Headers; {MCPConstants.ContentLength, 0}];
            response = prodserver.mcp.internal.signatureHandler(req);
            result = prodserver.mcp.internal.decodeBody(response);
            test.verifyTrue(isstruct(result));
            test.verifyTrue(isempty(fieldnames(result)));
            allowed = prodserver.mcp.internal.getHeaderValue('Allow', ...
                response.Headers);
            test.verifyEqual(allowed,'GET, POST, OPTIONS');
        end

        function echoesOnlyIssuedSessions(test)
        % A session ID this server issued is echoed back; any other isn't,
        % so a client can't make the response headers arbitrarily long.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.protocol.v20250618.Constants
            token = prodserver.mcp.test.sessionToken();
            b64 = @(s) char(prodserver.mcp.internal.base64encode( ...
                unicode2native(s, "UTF-8"), URLSafe=true));
            % Too long, but otherwise readable: refused for its length.
            tooLong = ['v1.' b64(['{"sid":"a","caps":{"experimental":' ...
                '{"pad":"' repmat('x', 1, 5000) '"}}}'])];
            cases = {token, true; ...
                char(matlab.lang.internal.uuid), false; ...
                ['v1.' repmat('A', 1, 5000)], false; ...
                tooLong, false; ...
                ['v1.' b64('{"sid":["a","b"],"caps":{}}')], false};
            for n = 1:size(cases, 1)
                req = test.request;
                req.Method = 'OPTIONS';
                req.Headers = [req.Headers; {MCPConstants.ContentLength, 0}; ...
                    {Constants.SessionId, cases{n,1}}];
                response = prodserver.mcp.internal.signatureHandler(req);
                echoed = prodserver.mcp.internal.getHeaderValue( ...
                    Constants.SessionId, response.Headers);
                label = extractBefore(string(cases{n,1}) + blanks(20), 20);
                if cases{n,2}
                    test.verifyEqual(string(echoed), string(token), label);
                else
                    test.verifyEmpty(echoed, "Echoed " + label);
                end
            end
        end

        function cathode(test)

            import prodserver.mcp.MCPConstants
        
            % Get base request structure
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, 'text/plain'}];
            req.Method = 'GET';

            % Test 1: All signatures (empty body)
            reqT = req;
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, 0}];
            response = prodserver.mcp.internal.signatureHandler(reqT);
            result = prodserver.mcp.internal.decodeBody(response);
            test.verifyTrue(all(ismember(["plotTrajectories","primeSequence"], ...
                fieldnames(result))));
            test.verifyEqual(numel(fieldnames(result)), 2);

            % Test 2: A single signature
            reqT = req;
            reqT.Method = 'POST';
            reqT.Body.Data = "plotTrajectories";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, strlength(reqT.Body.Data)}];
            response = prodserver.mcp.internal.signatureHandler(reqT);
            result = prodserver.mcp.internal.decodeBody(response);
            test.verifyTrue(all(ismember(reqT.Body.Data, fieldnames(result))));
            test.verifyEqual(numel(fieldnames(result)), 1);

            % Test 3: Multiple signatures -- all spaced out
            body = ["plotTrajectories,primeSequence", ...
                "plotTrajectories, primeSequence", ...
                "            plotTrajectories     ,     primeSequence   "];
            for b = body
                reqT = req;
                reqT.Method = 'POST';
                reqT.Body.Data = b;
                reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, strlength(reqT.Body.Data)}];
                response = prodserver.mcp.internal.signatureHandler(reqT);
                result = prodserver.mcp.internal.decodeBody(response); 
                test.verifyTrue(all(ismember(["plotTrajectories","primeSequence"], ...
                    fieldnames(result))));
                test.verifyEqual(numel(fieldnames(result)), 2);
            end

            % Test 4: Signature that doesn't exist -- should return empty.
            reqT = req;
            reqT.Method = 'POST';
            reqT.Body.Data = "unknownUnknowns";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, strlength(reqT.Body.Data)}];
            response = prodserver.mcp.internal.signatureHandler(reqT);
            result = prodserver.mcp.internal.decodeBody(response);
            test.verifyTrue(isstruct(result));
            test.verifyTrue(isempty(fieldnames(result)));
        end

        function anode(test)
            import prodserver.mcp.MCPConstants

            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, 'application/json'};
                {MCPConstants.ContentLength, '0'}];

            body = { 17, { struct.empty }, struct('x',21), 867.5309, ...
                "NotAFunction"};
            code = [400, 400, 400, 400, 404];
            for n = 1:numel(body)
                reqT = req;
                reqT.Method = 'POST';
                reqT.Body = body{n};
                reqT = prodserver.mcp.internal.encodeBody(reqT);
                reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(reqT.Body)}];
                response = prodserver.mcp.internal.signatureHandler(reqT);
                test.verifyEqual(response.HttpCode, code(n));
            end
        end
    end
end