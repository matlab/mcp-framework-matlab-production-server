classdef tSignature < HandlerBase
% Test signature handler

    methods (Test)

        function cathode(test)

            import prodserver.mcp.MCPConstants
        
            % Get base request structure
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, 'text/plain'}];

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
            reqT.Body.Data = "unknownUnknowns";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, strlength(reqT.Body.Data)}];
            response = prodserver.mcp.internal.signatureHandler(reqT);
            result = prodserver.mcp.internal.decodeBody(response);
            test.verifyTrue(isempty(result));
        end

        function anode(test)
            import prodserver.mcp.MCPConstants

            req =test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, 'application/json'}];

            body = { 17, { struct.empty }, struct('x',21), 867.5309 };
            for b = body
                reqT = req;
                reqT.Body = b{1};
                reqT = prodserver.mcp.internal.encodeBody(reqT);
                reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(reqT.Body)}];
                test.verifyError(...
                    @()prodserver.mcp.internal.signatureHandler(reqT), ...
                    "prodserver:mcp:InvalidSignatureListType", class(b{1}));
            end
        end
    end
end