classdef Constants
%Constants Protocol-specific constants for MCP v2026-07-28.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Version = "2026-07-28"

        % How a tools/call reports arguments that fail validation.
        %   2026-07-28 makes a tools/call whose arguments fail the tool's
        %   inputSchema -- a missing required argument, a wrong type -- a tool
        %   execution error (isError), so the model reads the message and
        %   can correct its call. An unknown tool stays -32602.
        InputErrorsAreToolErrors = true

        % HTTP headers introduced by this revision
        McpMethod = 'Mcp-Method'
        McpName = 'Mcp-Name'

        % Base64 header sentinel. Lowercase and case-sensitive, per the
        % spec; here rather than at the encoder and the decoder so the two
        % cannot disagree about the delimiter they share.
        HeaderSentinelPrefix = "=?base64?"
        HeaderSentinelSuffix = "?="

        % Error codes introduced by this revision (MCP-specific, outside the
        % JSON-RPC 2.0 reserved range)
        ErrorHeaderMismatch = -32020
        ErrorMissingCapability = -32021
        ErrorUnsupportedVersion = -32022

        % _meta subfield aliases: MATLAB field name -> JSON wire name
        % jsondecode mangles dots/slashes to underscores on input;
        % these pairs reverse that on output.
        MetaProtocolVersion_Field = "io_modelcontextprotocol_protocolVersion"
        MetaProtocolVersion_JSON  = "io.modelcontextprotocol/protocolVersion"
        MetaCapabilities_Field    = "io_modelcontextprotocol_clientCapabilities"
        MetaCapabilities_JSON     = "io.modelcontextprotocol/clientCapabilities"
        MetaCapabilitiesAlt_Field = "io_modelcontextprotocol_capabilities"
        MetaClientInfo_Field      = "io_modelcontextprotocol_clientInfo"
        MetaClientInfo_JSON       = "io.modelcontextprotocol/clientInfo"
        MetaLogLevel_Field        = "io_modelcontextprotocol_logLevel"
        MetaLogLevel_JSON         = "io.modelcontextprotocol/logLevel"
        MetaServerInfo_Field      = "io_modelcontextprotocol_serverInfo"
        MetaServerInfo_JSON       = "io.modelcontextprotocol/serverInfo"
        MetaSubscriptionId_Field  = "io_modelcontextprotocol_subscriptionId"
        MetaSubscriptionId_JSON   = "io.modelcontextprotocol/subscriptionId"
    end

end
