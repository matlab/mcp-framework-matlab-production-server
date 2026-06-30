classdef Constants

% Copyright 2025-2026 The MathWorks, Inc.

     properties (Constant)

        % MATLAB cast-able types
        castType = ["int8", "uint8", "int16", "uint16", "int32", ...
            "uint32", "int64", "uint64", "double", "single", "logical", ...
            "char"];

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

        % User specified schema data in comments starts with this string.
        Schema = "#schema";
        SchemaField = "schema";

        DefaultPersistVar = "xyzzy";

        HTTPClientError = 400;
        HTTPServerError = 500;

        MultiMCOSEnvVar = "MW_MULTIMCOS_MODE";

        % MIME types
        % Additional MIME types
        MIMETypeJSON = "application/json";
        MIMETypePlainText = "text/plain";

        % Argument info syntax patterns and constants
        ParameterSizePattern = textBoundary("start") + "(" + ...
            asManyOfPattern(characterListPattern("1234567890,: "),1,Inf) + ")";
        TypePattern = textBoundary("start") + lettersPattern + ...
            asManyOfPattern(alphanumericsPattern(1) | "_", 1, Inf);
        ValidationPattern = textBoundary("start") + "{" + wildcardPattern(Except="}") + "}";
        DefaultPattern = lookBehindBoundary("=") + wildcardPattern + ...
            textBoundary("end");

        % HTTP session ID - RFC 7329
        SessionIDPrefix = "SID";
        SessionIDSep = ":";
        SessionIDType = "MathWorks-Production-MCP-Server";
        SessionIDHeader = "Session-ID";
        SessionIDPattern = ...
            prodserver.mcp.internal.Constants.SessionIDPrefix + ...
            prodserver.mcp.internal.Constants.SessionIDSep + ...
            prodserver.mcp.internal.Constants.SessionIDType + ...
            prodserver.mcp.internal.Constants.SessionIDSep + ...
            asManyOfPattern(wildcardPattern(Except=prodserver.mcp.internal.Constants.SessionIDSep)) + ...
            prodserver.mcp.internal.Constants.SessionIDSep + ...
            wildcardPattern(36);

        % Session ID at the end of an HTTP path
        SessionIDAtEnd = lookBehindBoundary(...
            prodserver.mcp.internal.Constants.URISep) + ...
            prodserver.mcp.internal.Constants.SessionIDPrefix + ...
            prodserver.mcp.internal.Constants.SessionIDSep + ...
            wildcardPattern(Except=prodserver.mcp.internal.Constants.URISep) + ...
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
