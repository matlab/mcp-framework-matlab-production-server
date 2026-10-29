classdef Constants

% Copyright 2025-2026 The MathWorks, Inc.

     properties (Constant)

        % MATLAB classes by how the wire encodings carry them: the one
        % list behind WireSupport, jsonParameterType, the encoders' and
        % the validator's messages.
        FloatClasses = ["double", "single"];
        IntegerClasses = ["int8", "uint8", "int16", "uint16", "int32", ...
            "uint32", "int64", "uint64"];
        NumericClasses = [prodserver.mcp.internal.Constants.IntegerClasses, ...
            prodserver.mcp.internal.Constants.FloatClasses];
        % Plain JSON values, in both encodings.
        JSONClasses = [prodserver.mcp.internal.Constants.NumericClasses, ...
            "logical", "char", "string", "struct", "cell"];
        % Both encodings, but plain JSON only by converting them.
        ConvertedClasses = ["datetime", "duration"];
        % Only the invertible encoding.
        InvertibleClasses = ["categorical", "table", "timetable"];

        % Tags schemaFromValue leaves in an observed schema, for
        % SchemaObserver to resolve. Internal: never published, and not
        % MCPConstants.MatlabClass_Field, which is.
        ClassTag = "x_matlabClass";       % A class JSON can't describe
        ScalarTag = "x_matlabScalar";     % Whether that value was scalar
        ElementsTag = "x_matlabElements"; % Tagged elements of a cell

        % MATLAB cast-able types
        castType = [prodserver.mcp.internal.Constants.NumericClasses, ...
            "logical", "char"];

        % Primitive (non-container) types
        primitiveType = [prodserver.mcp.internal.Constants.castType, ...
            "string"];

        % Structured-string syntax
        PathSep = "/";
        URISep = "/";
        ParamStart = "?";
        ParamSep = "&";
        SchemeSuffix = ":";
        UserInfoSuffix = "@";
        AuthorityPrefix = "//";
        PortPrefix = ":"
        ExtSep = ".";
        FragStart = "#";
        InvalidInURI = string(char(":/?#[]@!$&'()*+,;=\")');

        % User specified schema data in comments starts with this string.
        Schema = "#schema";
        SchemaField = "schema";

        DefaultPersistVar = "xyzzy";

        % The header in which <archive>/ping names the build answering
        % (see archiveUUID), so that deploy can tell the archive it
        % uploaded from the one it replaces.
        ArchiveUUIDHeader = 'MATLAB-MCP-Archive-UUID';

        % Seconds deploy waits for /api/discovery to say which build an
        % archive that doesn't send that header is. Server metadata answers
        % at once or not usefully at all.
        DiscoveryTimeout = 10;

        % HTTP statuses sendRequest retries: the only ones that can change
        % while the request does not. 404 is Production Server's answer
        % while an archive is still being unpacked.
        RetryableStatus = [404 408 429];

        MultiMCOSEnvVar = "MW_MULTIMCOS_MODE";

        % MIME types
        % Additional MIME types
        MIMETypeJSON = "application/json";
        MIMETypePlainText = "text/plain";
        MIMETypeBinary = "application/octet-stream";

        % Argument info syntax patterns and constants
        ParameterSizePattern = textBoundary("start") + "(" + ...
            asManyOfPattern(characterListPattern("1234567890,: "),1,Inf) + ")";
        TypePattern = textBoundary("start") + lettersPattern + ...
            asManyOfPattern(alphanumericsPattern(1) | "_", 1, Inf);
        ValidationPattern = textBoundary("start") + "{" + wildcardPattern(Except="}") + "}";
        DefaultPattern = lookBehindBoundary("=") + wildcardPattern + ...
            textBoundary("end");

        % Single hexadecimal digit
        hexPattern = digitsPattern(1) | characterListPattern("ABCDEFabcdef");
        % Percent-encoded character pattern
        percentPattern = "%" + prodserver.mcp.internal.Constants.hexPattern + ...
            prodserver.mcp.internal.Constants.hexPattern;

        % Variables stored in the workspace only -- no persistence.
        WorkspaceScheme = "workspace:"

        % Scheme name, per RFC 3986.  
        % scheme = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
        SchemeName = lettersPattern(1) + optionalPattern(...
            asManyOfPattern(alphanumericsPattern(1) | "+" | "." | "-"));

        SchemeNamePattern = textBoundary("start") + ...
            prodserver.mcp.internal.Constants.SchemeName;

        % Scheme prefix: <name>:
        SchemePattern = textBoundary("start") + ...
            prodserver.mcp.internal.Constants.SchemeName + ...
            prodserver.mcp.internal.Constants.SchemeSuffix;

        % Match a file name extension
        ExtensionPattern = "." + wildcardPattern(Except=".");

        % A directory segment: one or more valid chars (no extension)
        PathSegment = asManyOfPattern(wildcardPattern(Except=characterListPattern("/"+newline)), 1);
        
        % Full path to a file.
        PathPattern = optionalPattern("/") + ...
            prodserver.mcp.internal.Constants.PathSegment + ...
            asManyOfPattern("/" + prodserver.mcp.internal.Constants.PathSegment, 0) + ...
            optionalPattern(prodserver.mcp.internal.Constants.ExtensionPattern);

    end
end
