classdef MCPConstants
%MCPConstants Constant values (DRY) related to the MCP protocol.
%Non-internal constants. Boundary between this enumeration and
%internal.Constants is a bit fuzzy, but generally internal.Constants is for
%values that the user never sees.

% Copyright 2025, The MathWorks, Inc.

    properties (Constant)

        SessionId = 'Mcp-Session-Id'
        ProtocolVersion = 'MCP-Protocol-Version';
        DefinitionFile = "McpServices.mat";
        DefinitionVariable = "mcpToolDefinition";
        ResourceVariable = "mcpServerResource";
        SignatureVariable = "signatures";
        ImporterVariable = "urlImport";
        NoWrapper = "None";
        ContentType = 'Content-Type';
        ContentLength = 'Content-Length';
        Host = 'Host';
        SSE = "/sse";
        MCP = "/mcp";
        Signature = "/signature";
        GroupName = "GroupName";
        WrapperFileSuffix = "MCP";
        ExternalParamSuffix = "URL";
        ExternOutGroup = "out";
        jrpcVersion = "2.0"
        protocolVersion = "2025-06-18";

        Array = "array";   % JSONRPC array type
        DefaultArgType = "double";  

        DefsField = "dollarDefs"; % Can't use $defs, so...
        DefsJSON = "$defs";

        %
        % Claude Code and the Claude desktop can't read resources as first
        % class objects (kind of ironic, considering Anthropic invented
        % MCP). So, provide a resource-reading tool -- and build it into
        % every server. Claude itself suggested both this workaround and
        % this tool name.
        %

        ReadResourceTool = "read_mcp_resource";

        % 
        % Details of the wire-encoding as an LLM-friendly resource. Claude
        % itself suggested the format. It better not have been
        % hallucinating.
        % 

        WireEncodingResourceURI = ...
            "mcp://protocol/tools/wire-format/parameters/encoding_rules";

        WireEncodingResource = struct( ...
            "uri", prodserver.mcp.MCPConstants.WireEncodingResourceURI, ...
            "contents", fullfile(fileparts(mfilename("fullpath")),...
                "+jsonrpc/wire_encoding_rules.txt"), ...
            "name", "tool-parameter-encoding-rules", ...
            "description", "A concise description of the rules used to " + ...
                "JSON encode and decode data passed as parameters to any " + ...
                "tool hosted by this server.", ...
            "title", "Tool parameter encoding and decoding rules", ...
            "mimeType", prodserver.mcp.internal.Constants.MIMETypePlainText);

        WireEncodingInputMsg = "You must encode data as described by this MCP resource: " + ...
            prodserver.mcp.MCPConstants.WireEncodingResourceURI;

        WireEncodingOutputMsg = "You must decode data as described by this MCP resource: " + ...
            prodserver.mcp.MCPConstants.WireEncodingResourceURI;

        WireEncodingRequiredMsg = "You must read the MCP resource " + ...
            prodserver.mcp.MCPConstants.WireEncodingResourceURI + ...
            " in full and completely understand it before making any " + ...
            "call to this tool.";

        %
        % Metrics
        %

        MCPRequestMetric = "MCP_Framework_Request";

        %
        % Function argument comments for the LLM
        %

        WrapTextLen = 72;   % Length at which to wrap text lines.

        NVPTag = "NVP";

        IndirectionMsg = "Refer to structuredContent for tool results.";

        OptionalGroupMsg = textwrap("This tool has optional inputs, " + ...
            "some of which may be pass-by-reference output locations.", ...
            prodserver.mcp.MCPConstants.WrapTextLen);

        %
        % Comments for all externalized inputs and outputs. Each
        % externalized parameter has the appropriate comments added to its
        % description.
        %

        ByReferenceInMsg = "URL from which input is read.";

        ByReferenceOutMsg = "Pass-by-reference output location. " + ...
            "Provide a writeable URL. This output never returned inline.";
        ByReferenceOutExample = ["file:///tmp/storage/data.csv", ...
            "file:///c:/tmp/storage/data.csv", ...
            "http://server/writable/resource (PUT endpoint)"];

        % Each externalized variable has an indirect schema
        ReferenceSchemaInputPrefix = "Write input to URL using ";
        ReferenceSchemaOutputPrefix = "Read result from URL using " + ...
            "schema-appropriate method: file system read for file: URLs, " + ...
            "HTTP GET for http:// URLs and so on. Data at the URL " + ...
            "formatted as ";

        % sprintf(ReferenceSchemaLocationFormat,io,name), where name is the
        % externalized name, such as xURL and io is the input/output
        % direction, i.e. input or output.
        ReferenceSchemaLocationFormat = """$ref"": ""#/$defs/%s/%s""";

        % Maximum number of elements in a literal array. Variables larger 
        % than this are passed by reference via URLs. Wrapper generation is
        % conservative: variables must be affirmatively known to be under
        % this limit to be passed as literals.
        MaxLiteralSize = 64;

        % Call and response
        Ping = "ping";
        Pong = "pong";

        % Map GenerativeAI enum values to environment variables
        GenAIEnvVar = dictionary( ...
            prodserver.mcp.GenerativeAI.OpenAI, "OPENAI_API_KEY", ...
            prodserver.mcp.GenerativeAI.Gemini, "GEMINI_API_KEY", ...
            prodserver.mcp.GenerativeAI.Anthropic, "ANTHROPIC_API_KEY", ...
            prodserver.mcp.GenerativeAI.Ollama, "", ...
            prodserver.mcp.GenerativeAI.Internal, "", ...
            prodserver.mcp.GenerativeAI.None, "");

        % Names of the environment variables containing the network 
        % address of the test server and the optional location of the test
        % data folder -- a test data folder may be necessary if the
        % server's file access is limited.
        TestServerEnvVar = "MW_MCP_MPS_TEST_SERVER";
        TestDataFolderEnvVar = "MW_MCP_MPS_TEST_DATA_FOLDER";
    end
end
