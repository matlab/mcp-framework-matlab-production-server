classdef tArgOrderREST < MCPCaller
% Use the REST interface to test argument order processing

% Copyright 2025-2026 The MathWorks, Inc.
    
    methods (TestMethodSetup)
        function scratchSpace(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
    
            % Temporary folder for intermediate / generated artifacts
            tfolder = TemporaryFolderFixture;
            applyFixture(test,tfolder);
            test.tempFolder = tfolder.Folder;
        end
    end

    methods 
        function [headers,payload] = buildToolsCall(test,tool)
            import prodserver.mcp.MCPConstants

            test.server = "http://localhost:9910/"+tool+"/mcp";

            payload.jsonrpc = "2.0";
            payload.method = "tools/call";
            payload.params.name = tool;

            headers = [...
                matlab.net.http.HeaderField('Content-Type', 'application/json'), ...
                matlab.net.http.HeaderField(MCPConstants.ProtocolVersion, ...
                    MCPConstants.protocolVersion)...
            ];
        end
    end

    methods(Test)

        function inputOrder(test)
            import prodserver.mcp.internal.hasField
            import prodserver.mcp.MCPConstants

            test.applyFixture(prodserver.mcp.test.mixin.RequireParamTools());

            fcn = "orderMatters";

            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,fcn));

            ctf = prodserver.mcp.build(fcn);
            endpoint = prodserver.mcp.deploy(ctf,test.host,test.port);

            % Call function directly to get expected outputs.
            % Inputs in the correct order.
            a = 4; b = 12; c = 3; d = 7;
            [eX,eY,eZ] = orderMatters(a,b,c,d);

            args.b = b;
            args.a = a;
            args.d = d;
            args.c = c;

            % Use MCP Framework tools to call the function
            [aX,aY,aZ] = prodserver.mcp.call(endpoint,fcn,a,b,c,d);
            test.verifyEqual(aX,eX,"X");
            test.verifyEqual(aY,eY,"Y");
            test.verifyEqual(aZ,eZ,"Z");

            % Initialize a new session
            [session,id] = prodserver.mcp.internal.initialize(endpoint, ...
                require="Tool");

            % REST call with arguments in the right order
            [headers,payload] = buildToolsCall(test,fcn);
            payload.id = id;
            headers = [headers, ...
     matlab.net.http.HeaderField(MCPConstants.SessionId, char(session))
            ];
 
            payload.params.arguments = orderfields(args,["a","b","c","d"]);

            body = matlab.net.http.MessageBody(payload);
            request = matlab.net.http.RequestMessage('POST', headers, body);
            response = send(request,endpoint);
            prodserver.mcp.internal.requireSuccess(response,endpoint, ...
                request=payload.method + " " + fcn);

            test.verifyTrue(hasField(response,...
                "Body.Data.result.structuredContent"),"structuredContent");

            result = response.Body.Data.result.structuredContent;
            test.verifyEqual(result.x,eX,"X");
            test.verifyEqual(result.y,eY,"Y");
            test.verifyEqual(result.z,eZ,"Z");

            % REST call with arguments in the wrong order
            outOfOrder = orderfields(args,["c","b","d","a"]);
            test.verifyEqual(jsonencode(outOfOrder), ...
                '{"c":3,"b":12,"d":7,"a":4}');
            
            payload.params.arguments = outOfOrder;

            body = matlab.net.http.MessageBody(payload);

            % Verify that arguments are in the wrong order in the payload.
            test.verifyEqual(jsonencode(body.Data.params.arguments), ...
                jsonencode(outOfOrder),"Argument order");

            request = matlab.net.http.RequestMessage('POST', headers, body);
            response = send(request,endpoint);
            prodserver.mcp.internal.requireSuccess(response,endpoint, ...
                request=payload.method + " " + fcn);

            test.verifyTrue(hasField(response,...
                "Body.Data.result.structuredContent"),"structuredContent");

            result = response.Body.Data.result.structuredContent;
            test.verifyEqual(result.x,eX,"X");
            test.verifyEqual(result.y,eY,"Y");
            test.verifyEqual(result.z,eZ,"Z");

        end

    end


end
