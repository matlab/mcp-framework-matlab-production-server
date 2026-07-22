classdef tOptionalHandlers < MCPHandlerBase
% Call the mcpHandler to invoke a function that has optional inputs.
    
    methods(Test)

        function optionalScalarInputs(test)

            import prodserver.mcp.internal.hasField
            import prodserver.mcp.test.mixin.RequireToyTools
            test.applyFixture(RequireToyTools);

            % Generate definitions required by the mcpHandler

            fcn = "toyScalarOptions";
            tool = "toyScalarOptions";

            defineTools(test,fcn,tool);
        
            % year, mpg, range, make, model
            params = {"year", "mpg", "range", "make", "model"};
            args = { 1999,1001,100000,"Polaris","Zeta" };

            % Start by calling with all arguments, then drop them,
            % one-by-one.
            for n = numel(args):-1:1
                % Call original for expected value
                expected = feval(fcn,args{1:n});

                % Call the function on the server.
                pN = params(1:n);
                aN = args(1:n);
                rArgs = { pN{:} ; aN{:} }; rArgs = rArgs(:)';
                request = createRequest(test,fcn,test.server,rArgs{:});
                response = prodserver.mcp.internal.mcpHandler(request);
                response = prodserver.mcp.internal.decodeBody(response);

                if hasField(response,"error")
                    test.verifyFalse(true,response.error.message);
                end
                test.verifyTrue(hasField(response,"result"),"No result field");
                test.verifyTrue(hasField(response.result,"structuredContent.report"), ...
                    "Missing output argument 'report'.");
                actual = string(response.result.structuredContent.report);
                test.verifyEqual(actual,expected,sprintf("Max arg #%d",n));
            end
        end
    end
end
