
function [status, message] = cleanSignalMCPEx(noisyURL, period, cleanURL)
    % cleanSignalMCPEx Wrapper for cleanSignal function
    %
    % Inputs:
    %   noisyURL: URL pointing to non-scalar input 'noisy' (double array)
    %   period: scalar input 'period' (double)
    %   cleanURL: URL where the non-scalar output 'clean' (double array) is to be saved
    %
    % Outputs:
    %   status: Boolean indicating the success of the function (true if successful)
    %   message: Message indicating 'OK' or containing error information

    arguments (Input)
        % A URL indicating the location from which the noisy input signal
        % should be read.
        noisyURL (1,1) string
        % The period (frequency) of the noise to remove from the signal.
        period (1,1) double
        % A URL indicating the location to which the clean output signal
        % should be written.
        cleanURL (1,1) string
    end

    arguments (Output)
        % Logical status representing success or failure: true for success,
        % false for failure.
        status (1,1) logical
        % Message indicating reason for success or failure.
        message (1,1) string
    end

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

