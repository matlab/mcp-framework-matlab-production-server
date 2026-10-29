classdef tDecodeBody < matlab.unittest.TestCase
% Test prodserver.mcp.internal.decodeBody, with emphasis on Content-Type
% normalization (a legal media type carries parameters and is
% case-insensitive) and on the opt-in strict mode used by the server's POST
% path.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        JSONBody = '{"jsonrpc":"2.0","id":1,"method":"tools/list"}';
    end

    methods

        function msg = request(~, contentType, body)
        % Build a MATLAB Production Server custom-web-handler message: an
        % Nx2 cell array of headers and a uint8 body.
            import prodserver.mcp.MCPConstants
            if nargin < 3
                body = '';
            end
            msg.Method = "POST";
            msg.Path = "/prime/mcp";
            if isempty(contentType)
                msg.Headers = cell(0,2);
            else
                msg.Headers = {char(MCPConstants.ContentType), char(contentType)};
            end
            if isempty(body)
                msg.Body = uint8.empty(1,0);
            else
                msg.Body = unicode2native(body, "UTF-8");
            end
        end

    end

    methods (Test)

        function tBareJSON(test)
            msg = test.request('application/json', test.JSONBody);
            data = prodserver.mcp.internal.decodeBody(msg, strict=true);
            test.verifyEqual(data.id, 1);
            test.verifyEqual(string(data.method), "tools/list");
        end

        function tCharsetParameterParsesIdentically(test)
            % G13: RFC 9110 makes parameters part of a legal Content-Type, so
            % a conformant client sending charset=utf-8 must not be rejected.
            bare = prodserver.mcp.internal.decodeBody( ...
                test.request('application/json', test.JSONBody), strict=true);
            withParam = prodserver.mcp.internal.decodeBody( ...
                test.request('application/json; charset=utf-8', test.JSONBody), ...
                strict=true);
            test.verifyEqual(withParam, bare);
        end

        function tParameterWithoutSpaceParses(test)
            data = prodserver.mcp.internal.decodeBody( ...
                test.request('application/json;charset=UTF-8', test.JSONBody), ...
                strict=true);
            test.verifyEqual(data.id, 1);
        end

        function tMediaTypeIsCaseInsensitive(test)
            data = prodserver.mcp.internal.decodeBody( ...
                test.request('APPLICATION/JSON', test.JSONBody), strict=true);
            test.verifyEqual(data.id, 1);
        end

        function tLeadingWhitespaceTolerated(test)
            data = prodserver.mcp.internal.decodeBody( ...
                test.request('  application/json  ', test.JSONBody), strict=true);
            test.verifyEqual(data.id, 1);
        end

        function tMalformedJSONIsParseError(test)
            % Correct Content-Type, unparseable body: -32700 / HTTP 400.
            msg = test.request('application/json', '{"jsonrpc":"2.0",');
            test.verifyError(@() prodserver.mcp.internal.decodeBody( ...
                msg, strict=true), "prodserver:mcp:ParseError");
        end

        function tEmptyBodyIsInvalidRequest(test)
            % Nothing is malformed because nothing is present: -32600, not
            % -32700.
            msg = test.request('application/json');
            test.verifyError(@() prodserver.mcp.internal.decodeBody( ...
                msg, strict=true), "prodserver:mcp:InvalidRequest");
        end

        function tUnsupportedMediaType(test)
            msg = test.request('text/plain', 'hello');
            test.verifyError(@() prodserver.mcp.internal.decodeBody( ...
                msg, strict=true), "prodserver:mcp:UnsupportedMediaType");
        end

        function tOctetStreamIsUnsupportedForRequests(test)
            % octet-stream is decodable by the permissive path, but it is not
            % a legal carrier for a JSON-RPC request, so strict mode must
            % reject it rather than hand back a deserialized MATLAB value.
            msg = test.request('application/octet-stream', 'nonsense');
            test.verifyError(@() prodserver.mcp.internal.decodeBody( ...
                msg, strict=true), "prodserver:mcp:UnsupportedMediaType");
        end

        function tMissingContentTypeWithBody(test)
            msg = test.request([], test.JSONBody);
            test.verifyError(@() prodserver.mcp.internal.decodeBody( ...
                msg, strict=true), "prodserver:mcp:UnsupportedMediaType");
        end

        function tNonStrictIsDefault(test)
            % Strict mode must stay opt-in: signatureHandler and the whole
            % client response path rely on an unrecognized Content-Type
            % falling through and on an empty body returning empty rather
            % than throwing.
            msg = test.request('text/plain', 'hello');
            data = prodserver.mcp.internal.decodeBody(msg);
            test.verifyEqual(string(data), "hello");

            empty = prodserver.mcp.internal.decodeBody( ...
                test.request('application/json'));
            test.verifyEmpty(empty);
        end

        function tNonStrictMalformedJSONStillThrows(test)
            % Permissive mode does not wrap the error, so the identifier is
            % MATLAB's own -- which is exactly why the POST path needs strict
            % mode to get a -32700 out of it.
            msg = test.request('application/json', '{"jsonrpc":"2.0",');
            test.verifyError(@() prodserver.mcp.internal.decodeBody(msg), ...
                ?MException);
        end

        function tResponseMessageDecodes(test)
            % The client side passes a ResponseMessage, which carries Header
            % (singular) rather than Headers.
            import matlab.net.http.ResponseMessage
            import matlab.net.http.MessageBody
            import matlab.net.http.field.ContentTypeField
            body = MessageBody(test.JSONBody);
            r = ResponseMessage(matlab.net.http.StatusCode.OK, ...
                ContentTypeField('application/json; charset=utf-8'), body);
            data = prodserver.mcp.internal.decodeBody(r);
            test.verifyEqual(data.id, 1);
        end

        function tResponseMessageLowercaseHeaderName(test)
            % Header names are case-insensitive (RFC 9110 §5.1). The Header
            % branch matched "Content-Type" exactly, so a server answering
            % "content-type" had its JSON returned undecoded.
            r = test.responseWith("content-type", "application/json");
            data = prodserver.mcp.internal.decodeBody(r);
            test.assertTrue(isstruct(data), "JSON body was not decoded");
            test.verifyEqual(data.id, 1);
        end

        function tResponseMessageMixedCaseValue(test)
            r = test.responseWith("CONTENT-TYPE", "Application/JSON ; charset=UTF-8");
            data = prodserver.mcp.internal.decodeBody(r);
            test.assertTrue(isstruct(data), "JSON body was not decoded");
            test.verifyEqual(data.id, 1);
        end

        function tResponseMessageWithoutHeaders(test)
            % No Header at all must fall through to the raw payload, not
            % index into an empty array.
            r = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode.OK, ...
                matlab.net.http.HeaderField.empty, ...
                matlab.net.http.MessageBody(test.JSONBody));
            r.Header = matlab.net.http.HeaderField.empty;
            data = prodserver.mcp.internal.decodeBody(r);
            test.verifyFalse(isstruct(data));
        end

        function tWhitespaceBodyIsInvalidRequest(test)
            % Whitespace is as empty as nothing, so the same -32600 -- not the
            % -32700 jsondecode would give it.
            msg = test.request('application/json', sprintf(" \t\r\n "));
            test.verifyError(@() prodserver.mcp.internal.decodeBody( ...
                msg, strict=true), "prodserver:mcp:InvalidRequest");
        end

        function tWhitespaceBodyWithoutContentType(test)
            % Nor a 415: there is no body whose type could be unsupported.
            msg = test.request([], sprintf("\n\n"));
            test.verifyError(@() prodserver.mcp.internal.decodeBody( ...
                msg, strict=true), "prodserver:mcp:InvalidRequest");
        end

        function tWhitespaceAroundJSONStillParses(test)
            % The complement: whitespace is only "empty" when it is all
            % there is.
            msg = test.request('application/json', ...
                sprintf("\n  %s  \n", test.JSONBody));
            data = prodserver.mcp.internal.decodeBody(msg, strict=true);
            test.verifyEqual(data.id, 1);
        end

        function tNonStrictWhitespaceIsUnchanged(test)
            % Permissive mode keeps its old behaviour for whitespace.
            msg = test.request('text/plain', '   ');
            data = prodserver.mcp.internal.decodeBody(msg);
            test.verifyEqual(string(data), "   ");
        end

    end

    methods (Access = private)

        function r = responseWith(test, name, value)
        % A ResponseMessage whose Content-Type field is spelled exactly as
        % given. A generic HeaderField, because ContentTypeField would
        % normalize the name.
            r = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode.OK, ...
                matlab.net.http.HeaderField(name, value), ...
                matlab.net.http.MessageBody(test.JSONBody));
        end

    end

end
