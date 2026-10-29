classdef Adapter < prodserver.mcp.client.Adapter
%Adapter Client adapter for MCP v2025-06-18.
%   Performs the `initialize` handshake and replays the returned
%   Mcp-Session-Id on subsequent requests.
%   Wraps the initialize/terminate session lifecycle.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Version = prodserver.mcp.protocol.v20250618.Constants.Version
    end

    properties (SetAccess = private)
        SessionId string = ""
    end

    methods

        function obj = Adapter(endpoint)
            obj@prodserver.mcp.client.Adapter(endpoint);
        end

        function connect(obj, opts)
            arguments
                obj
                opts.require prodserver.mcp.Primitive = "None"
                opts.timeout double {mustBePositive} = 60
                opts.retry double {mustBePositive} = 30
                opts.delay double {mustBePositive} = 2
            end
            [obj.SessionId, obj.RequestId] = ...
                prodserver.mcp.internal.initialize(obj.Endpoint, ...
                    require=opts.require, timeout=opts.timeout, ...
                    retry=opts.retry, delay=opts.delay);
        end

        function disconnect(obj)
            if strlength(obj.SessionId) > 0
			    try
					prodserver.mcp.internal.terminate(obj.Endpoint, ...
						obj.SessionId);
					obj.SessionId = "";
			    catch ex
				    warning("prodserver:mcp:TerminateFailed", "Failed to terminate " + ...
                        "session '%s': %s", obj.SessionId, ex.message);    
				end
            end
        end

        function [data, extraHeaders] = prepareRequest(obj, data)
        %prepareRequest The session header is this revision's whole envelope.
            extraHeaders = obj.protocolHeaders();
        end

        function headers = protocolHeaders(obj)
            import prodserver.mcp.protocol.v20250618.Constants
            headers = matlab.net.http.HeaderField( ...
                Constants.SessionId, char(obj.SessionId));
        end

    end

end
