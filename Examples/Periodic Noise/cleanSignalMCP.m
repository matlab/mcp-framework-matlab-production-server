
function [status, message] = cleanSignalMCP(noisyURL, period, cleanURL)
    % cleanSignalMCP Wrapper for cleanSignal function
    %
    % Inputs:
    %   noisyURL: URL pointing to non-scalar input 'noisy' (double array)
    %   period: scalar input 'period' (double)
    %   cleanURL: URL where the non-scalar output 'clean' (double array) is to be saved
    %
    % Outputs:
    %   status: Boolean indicating the success of the function (true if successful)
    %   message: Message indicating 'OK' or containing error information

    status = true;
    message = "OK";
    marshaller = prodserver.mcp.io.MarshallURI();

    try
        noisy = deserialize(marshaller, noisyURL);
        % Call the actual cleanSignal function
        clean = cleanSignal(noisy{1}, period);
        serialize(marshaller, cleanURL, {clean});
    catch ex
        status = false;
        message = ex.message;
    end
end

