classdef tMediaType < matlab.unittest.TestCase
% Media types compare case-insensitively and without their parameters, and
% decodeBody finds Content-Type whatever the case of the header name.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        % Each value and the bare media type it must reduce to.
        spelling = struct( ...
            'plain',      {{"application/json", "application/json"}}, ...
            'charset',    {{"application/json; charset=utf-8", "application/json"}}, ...
            'noSpace',    {{"application/json;charset=UTF-8", "application/json"}}, ...
            'upper',      {{"APPLICATION/JSON", "application/json"}}, ...
            'mixed',      {{"Application/JSON", "application/json"}}, ...
            'padded',     {{"  text/plain ; q=0.5", "text/plain"}}, ...
            'quality',    {{"text/event-stream;q=0.9", "text/event-stream"}}, ...
            'charVector', {{'Text/HTML', "text/html"}});

        % Every shape decodeBody reads headers from, each with the
        % Content-Type header name in lower case.
        headerShape = {"mpsCell", "headerField", "nameValueStruct"};
    end

    methods (Test)

        function bareMediaType(test, spelling)
            test.verifyEqual( ...
                prodserver.mcp.internal.mediaType(spelling{1}), spelling{2});
        end

        function arrayInArrayOut(test)
        % demandsEventStream passes every range of an Accept header at once.
            mt = prodserver.mcp.internal.mediaType( ...
                ["text/event-stream" "Application/JSON;q=0.9"]);
            test.verifyEqual(mt, ["text/event-stream" "application/json"]);
        end

        function absentIsEmptyText(test)
        % getHeaderValue answers [] for a missing header. That must compare
        % unequal to every media type rather than raise.
            mt = prodserver.mcp.internal.mediaType([]);
            test.verifyEqual(mt, "");
            test.verifyFalse(mt == "application/json");
        end

        function lowerCaseHeaderNameIsFound(test, headerShape)
        % Header names are case-insensitive. A name matched exactly misses
        % "content-type", and the body is then decoded as whatever an absent
        % header means rather than what the sender declared -- here, octet
        % stream bytes would be handed to jsondecode.
            value = primes(13);
            ct = 'application/octet-stream';
            switch headerShape
                case "mpsCell"
                    msg.Headers = {'content-type' ct};
                    msg.Body = getByteStreamFromArray(value);
                case "headerField"
                    msg.Headers = matlab.net.http.field.GenericField( ...
                        'content-type', ct);
                    msg.Body.Data = getByteStreamFromArray(value);
                case "nameValueStruct"
                    msg.Header = struct('Name', 'content-type', 'Value', ct);
                    msg.Body.Data = getByteStreamFromArray(value);
            end

            data = prodserver.mcp.internal.decodeBody(msg);
            test.verifyEqual(data, value);
        end

        function jsonWithParametersIsDecoded(test)
        % The defect as reported: a JSON body declared with a charset
        % parameter, and with the type in mixed case, arriving through MPS.
            body = '{"jsonrpc":"2.0","id":4,"method":"ping"}';
            msg.Headers = {'Content-Type' 'Application/JSON; charset=utf-8'};
            msg.Body = unicode2native(body, "UTF-8");

            data = prodserver.mcp.internal.decodeBody(msg);
            test.verifyEqual(data, jsondecode(body));
        end

        function responseMessageWithoutHeaders(test)
        % The old Header branch indexed msg.Header(1), so a ResponseMessage
        % with no headers at all raised instead of returning the payload.
            body = '{"jsonrpc":"2.0","id":4,"result":{}}';
            r = matlab.net.http.ResponseMessage( ...
                matlab.net.http.StatusCode.OK, ...
                matlab.net.http.HeaderField.empty, ...
                matlab.net.http.MessageBody(body));
            r.Header = matlab.net.http.HeaderField.empty;
            data = prodserver.mcp.internal.decodeBody(r);
            test.verifyEqual(data, jsondecode(body));
        end

    end
end
