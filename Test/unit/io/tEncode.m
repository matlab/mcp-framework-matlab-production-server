classdef tEncode < matlab.unittest.TestCase
% Test encode / decode of HTTP message body.

    properties
        tempDir
    end

    methods (TestClassSetup)
        function initFolder(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            test.tempDir = TemporaryFolderFixture(WithSuffix="sp a ce");
            test.applyFixture(test.tempDir);
        end
    end

    methods (Test)

        function msgBody(test)

            import matlab.net.http.field.ContentTypeField
            import prodserver.mcp.internal.hasField
            import prodserver.mcp.MCPConstants

            % Two different kinds of messages use two different names for
            % their field of HTTP message headers. 
            headers = [ "Header", "Headers" ];

            contentType = [ "application/json", "application/octet-stream", ...
                "text/plain", "text/html" ];

            actual = { ...
                struct('x',3,'y',4,'z',5), ...
                primes(13), ...
                "This is plain text. Completely ordinary.", ...
                "<b>This</b> is <em>HTML</em>. Not ordinary at all." ...
             };
             expected.Headers = {...
                jsonencode(actual{1}), ...
                getByteStreamFromArray(actual{2}), ...
                unicode2native(actual{3},"UTF-8"),...
                unicode2native(actual{4},"UTF-8"), ...
            };

             expected.Header = {...
                 unicode2native(jsonencode(actual{1}),"UTF-8"), ...
                 getByteStreamFromArray(actual{2}), ...
                 unicode2native(actual{3},"UTF-8"),...
                 unicode2native(actual{4},"UTF-8"), ...
                 };


            % Fake message
            for h = 1:numel(headers)
                answer = expected.(headers(h));
                for c = 1:numel(contentType)
                    % Set content type and content
                    if strcmpi(headers(h),"Headers")
                        msg.(headers(h)) = ContentTypeField(contentType(c));
                        msg.Body.Data = actual{c};
                    else
                        hdr.Name = prodserver.mcp.MCPConstants.ContentType;
                        hdr.Value = contentType(c);

                        msg.(headers(h)) = hdr;
                        msg.Body = actual{c};
                    end

                    % Verify encoding.

                    test.verifyTrue(isstruct(msg),"Before encoding, H = " ...
                        + string(h) + " N = " + string(c));
                    msg = prodserver.mcp.internal.encodeBody(msg);
                    test.verifyTrue(isstruct(msg),"After encoding, H = " ...
                        + string(h) + " N = " + string(c));

                    if hasField(msg,"Body.Payload")
                        test.verifyEqual(msg.Body.Payload, answer{c}, ...
                            "Body.Payload, N = "+ string(c));
                    else
                        test.verifyEqual(msg.Body,answer{c},"Body N = " ...
                            + string(c));
                    end

                    % Decode

                    data = prodserver.mcp.internal.decodeBody(msg);
                    if startsWith(contentType{c},"text/")
                        data = string(data);
                    end
                    test.verifyEqual(data,actual{c});
            
                    % Reset structure
                    msg = [];
                end
            end
        end

    end


end
