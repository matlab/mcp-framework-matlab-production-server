classdef Adapter < prodserver.mcp.client.Adapter
%Adapter Client adapter for MCP v2026-07-28.
%   Skips the handshake and stamps params._meta on every request instead.
%   No session lifecycle. Injects _meta into every request body
%   and MCP-Protocol-Version into every request header.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Version = prodserver.mcp.protocol.v20260728.Constants.Version
    end

    methods

        function obj = Adapter(endpoint)
            obj@prodserver.mcp.client.Adapter(endpoint);
        end

        function connect(~, opts) %#ok<INUSD>
            arguments
                ~
                opts.require = "None"
                opts.timeout = 60
                opts.retry = 30
                opts.delay = 2
            end
        end

        function disconnect(~)
        end

        function [data, extraHeaders] = prepareRequest(obj, data)
        %prepareRequest Add this revision's _meta envelope and headers.
        %   Returns an ARRAY of headers: MCP-Protocol-Version always,
        %   Mcp-Method always, and Mcp-Name for the three methods that name
        %   a thing. All three are required of a client by this revision,
        %   and the server enforces all three strictly (see
        %   v20260728.validateHeaders), so omitting any one earns a
        %   -32020/400 on a request that was otherwise correct.
        %
        %   The version header is protocolHeaders', the per-message rows
        %   v20260728.messageHeaders', so neither is built a second time
        %   here.
            data = prodserver.mcp.protocol.v20260728.stampMeta(data);

            extraHeaders= obj.protocolHeaders();
            rows = prodserver.mcp.protocol.v20260728.messageHeaders(data);
            for k = 1:size(rows, 1)
                extraHeaders = [extraHeaders, ...
                    matlab.net.http.HeaderField(rows{k,1}, rows{k,2})]; %#ok<AGROW>
            end
        end

        function headers = protocolHeaders(~)
            C = prodserver.mcp.protocol.v20260728.Constants;
            headers = matlab.net.http.HeaderField( ...
                prodserver.mcp.MCPConstants.ProtocolVersion, ...
                char(C.Version));
        end

        function json = postEncode(~, json)
            json = prodserver.mcp.protocol.v20260728.restoreJSONFields(json);
        end

    end

end
