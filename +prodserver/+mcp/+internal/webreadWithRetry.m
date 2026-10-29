function [result, lastError] = webreadWithRetry(url, webOpts, opts)
%webreadWithRetry webread URL until it gives an acceptable answer.
%   [RESULT, LASTERROR] = webreadWithRetry(URL, WEBOPTS, Name=Value) calls
%   webread(URL, WEBOPTS) up to opts.attempts times and returns the first
%   result opts.accept accepts.
%
%     attempts   Most webread calls to make. Below 1 makes none.
%     delay      Seconds to pause between attempts.
%     retryable  @(MException) -> logical. A failure it rejects is rethrown
%                at once; a failure it accepts is retried.
%     accept     @(result) -> logical. A result it rejects is retried too.
%
%   When the attempts run out, RESULT is the last result read ([] if none)
%   and LASTERROR the failure of the last attempt (empty if it read an
%   answer, however unacceptable), so the caller
%   chooses between reporting the error and reporting the absence of an
%   answer.
%
%   The pause comes only when another attempt is actually coming (ND11):
%   pausing after the last one only delays the diagnosis. The one loop for
%   isserver, metrics, ping and the archive listing; the copies it replaced
%   had already drifted on exactly that point.

% Copyright 2026 The MathWorks, Inc.

    arguments
        url (1,1) string
        webOpts
        opts.attempts (1,1) double = 1
        opts.delay (1,1) double = 0
        opts.retryable (1,1) function_handle = @(~) false
        opts.accept (1,1) function_handle = @(~) true
    end

    result = [];
    lastError = MException.empty;
    for n = 1:opts.attempts
        try
            result = webread(url, webOpts);
            lastError = MException.empty;   % The latest outcome is an answer.
            if opts.accept(result)
                return
            end
        catch me
            if ~opts.retryable(me)
                rethrow(me);
            end
            lastError = me;
        end
        if n < opts.attempts && opts.delay > 0
            pause(opts.delay);
        end
    end
end
