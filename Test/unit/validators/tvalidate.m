classdef tvalidate < matlab.unittest.TestCase
    methods (Test)
        function positiveInteger(test)

            import prodserver.mcp.validation.mustBePositiveInteger

            mustBePositiveInteger(19);
            mustBePositiveInteger(1);
            mustBePositiveInteger(10e6-1);

            test.verifyError(@()mustBePositiveInteger(0), ...
                "MATLAB:expectedPositive");

            test.verifyError(@()mustBePositiveInteger(-273), ...
                "MATLAB:expectedPositive");

            test.verifyError(@()mustBePositiveInteger(3.14), ...
                "MATLAB:expectedInteger");

            test.verifyError(@()mustBePositiveInteger(-2.17), ...
                "MATLAB:expectedInteger");
        end

        function fcn(test)
            import prodserver.mcp.validation.mustBeFunction

            mustBeFunction("sin");
            mustBeFunction("prodserver.mcp.build");
            mustBeFunction(["sin", "prodserver.mcp.build"]);
            test.verifyTrue(prodserver.mcp.validation.isfcn("validNameButDoesNotExist"));
            mustBeFunction(@plus);
            mustBeFunction(@(x)x+1);

            tf = prodserver.mcp.validation.isfcn(["eig", "p_equals_np", "times"],true);
            test.verifyEqual(tf,[true,false,true]);

            % Make sure function name shows up in error message.
            try
                mustBeFunction(["eig", "p_equals_np", "times"]);
                msg = "";
                id = "";
            catch ex
                msg = ex.message;
                id = ex.identifier;
            end
            test.verifyTrue(contains(msg, "p_equals_np"), msg);
            test.verifyEqual(id,'prodserver:mcp:FunctionNotFound');

            test.verifyError(@()mustBeFunction(@nonExistent), ...
                "prodserver:mcp:FunctionNotFound");

            test.verifyError(@()mustBeFunction("validNameButDoesNotExist"), ...
                "prodserver:mcp:FunctionNotFound");

            test.verifyError(@()mustBeFunction(12), ...
                "prodserver:mcp:FunctionNotFound");

            test.verifyError(@()mustBeFunction("1cannotBeFirstCharacter"), ...
                "prodserver:mcp:FunctionNotFound");

            test.verifyError(@()mustBeFunction("this.is%not.a.valid.name"), ...
                "prodserver:mcp:FunctionNotFound");
        end

        function hostName(test)
            import prodserver.mcp.validation.mustBeHostName

            mustBeHostName("localhost");
            mustBeHostName("mathworks.com");
            mustBeHostName("a.b.c.d.e");
            mustBeHostName("a.-.b"); % Really?
            mustBeHostName("127.0.0.1");
            mustBeHostName("this-is-a-host.com");

            test.verifyError(@()mustBeHostName(12), ...
                "MATLAB:validators:mustBeTextScalar");

            test.verifyError(@()mustBeHostName(["local", "host"]), ...
                "MATLAB:validators:mustBeTextScalar");

            test.verifyError(@()mustBeHostName("local%host"), ...
                "prodserver:mcp:BadHostName");

            test.verifyError(@()mustBeHostName("#1.host.com"), ...
                "prodserver:mcp:BadHostName");
        end

        function mcpServer(test)
            import prodserver.mcp.validation.mustBeMCPServer

            mustBeMCPServer("http://localhost:9910/mcp");
            mustBeMCPServer("http://localhost:9910/archive/tool/mcp");

            % Invalid URLs
            test.verifyError(@()mustBeMCPServer("http:/localhost:9910/mcp"), ...
                "prodserver:mcp:InvalidServerAddress");

            test.verifyError(@()mustBeMCPServer("http://local$host:9910/mcp"), ...
                "prodserver:mcp:InvalidServerAddress");

            % Valid URL, but not an MCP endpoint because it ends with
            % query parameters.
            test.verifyError(@()mustBeMCPServer("http://local$host:9910/mcp?param=value"), ...
                "prodserver:mcp:InvalidServerAddress");

            % Bad types
            test.verifyError(@()mustBeMCPServer(17), ...
                "MATLAB:validators:mustBeTextScalar");

            test.verifyError(@()mustBeMCPServer(@sin), ...
                "MATLAB:validators:mustBeTextScalar");

            test.verifyError(@()mustBeMCPServer({''}), ...
                "MATLAB:validators:mustBeTextScalar");

            test.verifyError(@()mustBeMCPServer(""), ...
                "prodserver:mcp:InvalidServerAddress");
        end

        function portNumber(test)
            import prodserver.mcp.validation.mustBePortNumber
            mustBePortNumber(666);
            mustBePortNumber(60000);
            mustBePortNumber(1);
            mustBePortNumber(intmax("uint16"));
            test.verifyError(@()mustBePortNumber([1,17,2001,8675]),...
                "MATLAB:mustBePortNumber:expectedScalar");
            test.verifyError(@()mustBePortNumber("9910"), ...
                "MATLAB:mustBePortNumber:invalidType");
        end

        function sameSize(test)
            import prodserver.mcp.validation.mustBeSameSize
            % mustBeSameSize(n,items): every element of items must be the
            % same size as items(n).

            mustBeSameSize(3,[1,2,4]);
            mustBeSameSize(1,"both strings", "are scalars");
            mustBeSameSize(2,"both strings", "are scalars");
            mustBeSameSize(3,"a scalar string", 17, ...
                struct('x',3,'y',4','z',5));
            mustBeSameSize(1, 1:10, string(1:10), zeros(1,10));
            mustBeSameSize(5, '', string.empty, struct.empty, {}, []);

            test.verifyError(@()mustBeSameSize(1,1,[2,3], 4), ...
                "prodserver:mcp:DifferentSize");
            test.verifyError(@()mustBeSameSize(1,magic(3),magic(4)), ...
                "prodserver:mcp:DifferentSize");
            test.verifyError(@()mustBeSameSize(1,1:10,1:5), ...
                "prodserver:mcp:DifferentSize");
            test.verifyError(@()mustBeSameSize(1,zeros(1,10),zeros(10,1)), ...
                "prodserver:mcp:DifferentSize");
        end

        function scheme(test)
            import prodserver.mcp.validation.mustBeScheme
            mustBeScheme("http");
            mustBeScheme("file");
            mustBeScheme("json");
            mustBeScheme("redis");
            mustBeScheme("this+that-the.Other");
            mustBeScheme("x127.0.0.1");   % Hmmmm.

            test.verifyError(@()mustBeScheme("127.0.0.1"), ...
                "prodserver:mcp:BadScheme");
            test.verifyError(@()mustBeScheme(81),"MATLAB:invalidType");
            test.verifyError(@()mustBeScheme(@sin),"MATLAB:invalidType");
            test.verifyError(@()mustBeScheme(''),"MATLAB:expectedNonempty");
            test.verifyError(@()mustBeScheme(""),"prodserver:mcp:BadScheme");
            test.verifyError(@()mustBeScheme({''}),"MATLAB:expectedScalartext");
            test.verifyError(@()mustBeScheme([]),"MATLAB:invalidType");

        end

        function toolDefinition(test)
            import prodserver.mcp.validation.mustBeToolDefinition
            d.tools.description = "Some descriptive text";
            d.tools.name = "TheNameOfTheTool";
            d.tools.inputSchema.required = ["x","y","z"];
            d.tools.inputSchema.type = "object";
            arg.type = "double";
            arg.description = "A very importart argument.";
            d.tools.inputSchema.properties = struct("x",arg,"y",arg,"z",arg);
            d.tools.outputSchema.type = "object";
            d.tools.outputSchema.properties = struct("q",arg,"s",arg);
            d.tools.outputSchema.required = ["q","s"];
            mustBeToolDefinition(d);
            mustBeToolDefinition(struct.empty);

            test.verifyError(@()mustBeToolDefinition(struct("name","tool")), ...
                "prodserver:mcp:ToolDefinitionMissingTools");

            bad.tools = rmfield(d.tools,"name");
            test.verifyError(@()mustBeToolDefinition(bad), ...
                "prodserver:mcp:MissingToolDefinitionField");

            bad = d;
            bad.tools.inputSchema = rmfield(bad.tools.inputSchema,"type");
            test.verifyError(@()mustBeToolDefinition(bad), ...
                "prodserver:mcp:MissingToolDefinitionField");

            mustBeToolDefinition(@sin);  % Test more deeply?
            test.verifyError(@()mustBeToolDefinition(@snork), ...
                "prodserver:mcp:ToolDefinitionGeneratorNotFound");

            mustBeToolDefinition("tvalidate.m");  % Deeper testing needed?
            test.verifyError(@()mustBeToolDefinition("not a file, for sure"), ...
                "MATLAB:validators:mustBeFile");

        end

        function uri(test)
            import prodserver.mcp.validation.mustBeURI
            mustBeURI("http://localhost:9910")
            mustBeURI("http://www.mathworks.com/products/compilerSDK");
            mustBeURI("file:/path/to/my/data/file.txt");
            mustBeURI("file:c:/path/to/my/data/file.txt");
            mustBeURI("http://us3r@h0st.com/pi");
            mustBeURI("http://user@host.com/path?p1=v1&p2=v2#location");

            test.verifyError(@()mustBeURI(18),"prodserver:mcp:BadURIType");
            test.verifyError(@()mustBeURI(@sin),"prodserver:mcp:BadURIType");
            test.verifyError(@()mustBeURI(struct('x',99)),"prodserver:mcp:BadURIType");

            test.verifyError(@()mustBeURI("file:$path/to/my/data/file.txt"),...
                "prodserver:mcp:BadURI");

            % TODO: This should fail, but doesn't.
            %test.verifyError(@()mustBeURI("scheme:/path/12??param=19"),...
            %    "prodserver:mcp:BadURI");

        end

        function wrapper(test)
            import prodserver.mcp.validation.mustBeWrapper

            mustBeWrapper(@sin);  % A function handle
            mustBeWrapper("tvalidate.m");  % An existing file.

            test.verifyError(@()mustBeWrapper(@wrapperGenerator), ...
                "prodserver:mcp:WrapperGeneratorNotFound");

            test.verifyError(@()mustBeWrapper("this is not the name of a file"), ...
                "MATLAB:validators:mustBeFile");
        end

    end
end
