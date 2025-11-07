function uri = percentDecode(uri)
%percentDecode Replace all percent-encodings in URI with their equivalent
%characters. 

% Copyright (c) 2025, The MathWorks, Inc.

    import prodserver.mcp.internal.Constants

    for n = 1:numel(uri)
        if isstruct(uri(n))
            fields = ["host", "userInfo", "path", "query"];
            for f = fields
                [uri(n).(f)] = prodserver.mcp.io.percentDecode([uri(n).(f)]);
            end
        elseif isstring(uri)
            % Is there a higher-level way to do this? Manipulation of
            % strings on a byte-by-byte basis feels vaguely uncomfortable.

            encodings = unique(extract(uri(n),Constants.percentPattern));
            if isempty(encodings) == false
                % Replace the three characters of each encoding with the
                % single byte of the decoding, without subjecting that byte
                % to any kind of interpretation as a character -- because
                % it might be part of a multi-btye UTF-8 sequence.

                % Each element in the cell array is a three-byte sequence
                % of integers < 256. These are the three-byte sequences we
                % must find in uri(n) and replace with the single UTF-8
                % byte of the decoding.
                u8e = arrayfun(@(e)unicode2native(e,"UTF-8"), ...
                    encodings, UniformOutput=false);

                % These are the single UTF-8 bytes that replace the
                % three-byte sequences in encodings. Both encodings and
                % decodings are in the same order.
                decodings = hex2dec(erase(encodings,"%"));

                % Now the string we're decoding is a sequence of integers.
                u8s = unicode2native(uri(n),"UTF-8");

                % Find each encoding (three bytes) and replace it (them)
                % with the corresponding single byte decoding.
                for k = 1:numel(u8e)
                    % Oddly, strfind is the recommended function here.
                    start = strfind(u8s,u8e{k});

                    % Each element of start is the position of the
                    % beginning of the three characters of encoding{n}.
                    % Place the decoded byte at each start(k), and then 
                    % delete the two bytes following each start(k).
                    u8s(start) = decodings(k);
                    toDelete = [start+1, start+2];
                    u8s(toDelete) = '';
                end    

                % Now convert the bytes back to a string. The UTF-8
                % bytes become a UTF-16 MATLAB string.
                uri(n) = string(native2unicode(u8s,"UTF-8"));
                
            end
        end
    end
end