classdef Log < handle
%Log The server-side log of one archive in a worker.
%
%   The framework creates no log file: every line goes to the worker's
%   stdout or stderr, and MPS copies it into main.log. A line is
%     [mcp:<level>] <id> <context> <message>
%   - <level> is the level name in lower case;
%   - <id> is a prodserver:mcp:<Name> identifier: a feature's event or
%     error identifier, or one of prodserver.mcp.logging.Event. It is
%     written through echo(quoted=false), so it is always one bounded
%     token: an identifier is unchanged, and any other value is escaped,
%     cut or described;
%   - <context> is id=<JSON-RPC id> trace=<traceparent> archive=<archive>_<n>
%     tool=<tool>, in that order, absent fields left out; with no field the
%     separating space is left out too;
%   - control characters are escaped, so one event is one line.
%   Warning and Error go to stderr, Trace and Information to stdout.
%
%     log = prodserver.mcp.logging.Log.instance();
%     log.log(prodserver.mcp.logging.Level.Warning, "prodserver:mcp:TouchFailed", ...
%         "touch failed: %s", reason);
%
%   Threshold. On an MPS instance, the last uncommented --log-severity in
%   <instanceRoot>/config/main_config, read once when the Log is made: error,
%   warning, information or trace, ignoring case. A missing or unreadable
%   file, or any other value: Information, and one
%   Event.LogSeverityUnavailable line. Off MPS there is no instance root,
%   and the threshold is Information with no line.
%
%   Logging never raises: log, logOnce, logOncePer, beginRequest,
%   setContext, level and instance, with any input.
%
%   Content. Log does not redact. A caller must not pass a secret, a
%   credential or a full mcpdata:// reference; each feature's rules for what
%   it may log are its own.
%
%   Formats. FMT is a format, read by sprintf: pass a constant, and put
%   caller text in the arguments, never in FMT, where its % sequences would
%   be read as conversions.
%
%   No contract checks. Nothing on Log's path, construction included, may
%   call prodserver.mcp.contract.enforce: the contract level's first read
%   logs through Log (an unknown MW_MPS_MCP_CONTRACTS), so a check here
%   would recurse.
%
%   One Log per archive: instance() keeps it in archiveCache, whose archive
%   scope is per deployed archive, so each Log names its own archive=.
%
%   See also prodserver.mcp.logging.Level, prodserver.mcp.logging.Event

% Copyright 2026 The MathWorks, Inc.

% Contract:
%   Invariant: the context holds only id, trace, archive and tool
%              archive is deployedArchiveLocation().folderName when it is <archive>_<n>,
%              else ""; fixed when the Log is made
%              no method raises

    properties (Hidden)
        % Test seam: a function handle f(stream, line), stream 1 or 2.
        Sink = @(stream, line) fprintf(stream, "%s\n", line)
        % Settable, so a test can enable Trace on any Log.
        Threshold (1,1) prodserver.mcp.logging.Level = prodserver.mcp.logging.Level.Information
    end

    properties (Access = private)
        Archive (1,1) string = ""
        Id (1,1) string = ""
        Tool (1,1) string = ""
        Trace = ""          % the field's text, or a function handle not yet called
        Seen                % logOnce, logOncePer: key -> posixtime of its last line
    end

    properties (Constant, Access = private)
        CacheName = "prodserver_mcp_log"
    end

    methods
        function obj = Log(opts)
        %Log A Log for one archive. instance() is the way to get one; the
        %   options are test seams: instanceRoot= names the folder whose
        %   config/main_config gives the threshold, archive= the archive=
        %   field, and sink= the Sink, set before main_config is read so a
        %   test sees the line a bad file writes.
            % Typed, as only tests pass options; sink isn't, so a non-handle is ignored.
            arguments
                opts.instanceRoot (1,1) string = missing
                opts.archive (1,1) string = missing
                opts.sink = []      % a function handle f(stream, line)
            end
            obj.Seen = configureDictionary("string", "double");
            if isa(opts.sink, "function_handle")
                obj.Sink = opts.sink;
            end
            try
                if ismissing(opts.instanceRoot) || ismissing(opts.archive)
                    where = prodserver.mcp.handler.deployedArchiveLocation();
                    if ismissing(opts.instanceRoot), opts.instanceRoot = where.instanceRoot; end
                    if ismissing(opts.archive)
                        % Off MPS ctfroot is matlabroot, not <archive>_<n>:
                        % there is no archive to name.
                        opts.archive = "";
                        if strlength(where.archiveName) > 0
                            opts.archive = where.folderName;
                        end
                    end
                end
                obj.Archive = opts.archive;
                obj.readThreshold(opts.instanceRoot);
            catch
                % A Log is always made: the threshold stays Information.
            end
        end

        function log(obj, lvl, id, fmt, varargin)
        %log Write one line if LVL is at or above the threshold.
        %   FMT and the arguments are formatted with sprintf, then escaped.
        %   FMT must be a constant; caller text goes in the arguments.

        % Contract:
        %   Kind:      command (writes at most one line)
        %   Requires:  none (any input)
        %   Ensures:   one line is written when lvl >= Threshold, none otherwise
        %              a lazy trace handle is evaluated at most once per request,
        %              only when a written line needs it
        %   Raises:    none
            % No types: a check here would raise before the try, and logging never raises.
            arguments
                obj
                lvl         % a prodserver.mcp.logging.Level, or its name
                id          % a prodserver:mcp:<Name> identifier
                fmt = ""    % a constant sprintf format; caller text goes in varargin
            end
            arguments (Repeating)
                varargin    % the arguments FMT formats
            end
            try
                lvl = prodserver.mcp.logging.Level(lvl);
                if lvl < obj.Threshold
                    return
                end
                line = obj.format(lvl, id, fmt, varargin);
                stream = 1 + (lvl >= prodserver.mcp.logging.Level.Warning);
                obj.Sink(stream, line);
            catch
                % Logging never raises.
            end
        end

        function logOnce(obj, key, lvl, id, fmt, varargin)
        %logOnce log, the first time KEY is seen by this Log.
        %   logOnce(OBJ, KEY, LVL, ID, FMT, ...) writes the line only if KEY,
        %   a string, has not been logged by this Log. Tracing's keys are
        %   <archive>|<identifier>. logOncePer logs a key again after an
        %   interval; the two share their keys.

        % Contract:
        %   Kind:      command
        %   Requires:  none (any input)
        %   Ensures:   the first call with a key logs as log does; later calls with it
        %              log nothing
        %   Raises:    none
            % No types: a check here would raise before the try, and logging never raises.
            arguments
                obj
                key         % a string: the throttle's key
                lvl         % a prodserver.mcp.logging.Level, or its name
                id          % a prodserver:mcp:<Name> identifier
                fmt = ""    % a constant sprintf format; caller text goes in varargin
            end
            arguments (Repeating)
                varargin    % the arguments FMT formats
            end
            obj.throttle(key, Inf, lvl, id, fmt, varargin);
        end

        function logOncePer(obj, key, interval, lvl, id, fmt, varargin)
        %logOncePer log, at most once per INTERVAL seconds for KEY.
        %   logOncePer(OBJ, KEY, INTERVAL, LVL, ID, FMT, ...) writes the line
        %   only if KEY, a string, has had no line from this Log in the last
        %   INTERVAL seconds: a line that comes sooner is dropped, so a
        %   steady failure logs once per interval (FD-17). An INTERVAL that
        %   is not a non-negative real number is Inf, so a bad interval
        %   logs once rather than every time.

        % Contract:
        %   Kind:      command
        %   Requires:  none (any input)
        %   Ensures:   a call logs as log does when KEY's last line is INTERVAL seconds old or
        %              more, or KEY has none; otherwise it logs nothing
        %   Raises:    none
            % No types: a check here would raise before the try, and logging never raises.
            arguments
                obj
                key         % a string: the throttle's key
                interval    % seconds, a non-negative real number
                lvl         % a prodserver.mcp.logging.Level, or its name
                id          % a prodserver:mcp:<Name> identifier
                fmt = ""    % a constant sprintf format; caller text goes in varargin
            end
            arguments (Repeating)
                varargin    % the arguments FMT formats
            end
            obj.throttle(key, interval, lvl, id, fmt, varargin);
        end

        function beginRequest(obj, jrpc)
        %beginRequest Start a request's context.
        %   Clears id, trace and tool, then sets id from JRPC.id when JRPC
        %   has one: a number as it is, text through echo(quoted=false). It
        %   does not read params._meta.traceparent: whoever chooses the trace
        %   sets it with setContext(trace=). mcpHandler calls beginRequest()
        %   first for every request, beginRequest(jrpc) once the body
        %   decodes, and beginRequest() again when the request ends. So a
        %   line written outside an MCP request, by an admin route or a
        %   function MPS calls directly, carries no request's fields.

        % Contract:
        %   Kind:      command (fields only; no I/O)
        %   Requires:  none (jrpc may be [], a struct, or anything)
        %   Ensures:   id, trace and tool from earlier requests are gone
        %              no file is read and nothing is written
        %   Raises:    none
            % No types: a check here would raise before the try, and logging never raises.
            arguments
                obj
                jrpc = []   % the decoded JSON-RPC message, or [] for none
            end
            try
                obj.Id = "";
                obj.Tool = "";
                obj.Trace = "";
                if isstruct(jrpc) && isscalar(jrpc) && isfield(jrpc, "id")
                    id = jrpc.id;
                    if prodserver.mcp.validation.isTextScalar(id) && strlength(id) == 0
                        % "" is an id, and an empty field would be left out.
                        obj.Id = """""";
                    elseif isempty(id)
                        % null, or no id at all.
                    elseif isnumeric(id) && isscalar(id) && isreal(id)
                        obj.Id = string(id);
                    else
                        obj.Id = prodserver.mcp.protocol.echo(id, quoted=false);
                    end
                end
            catch
                % Logging never raises.
            end
        end

        function setContext(obj, varargin)
        %setContext Add to the request context: tool=NAME, trace=TC.
        %   setContext(OBJ, tool=NAME) sets tool=. setContext(OBJ, trace=TC)
        %   sets trace= to TC.TraceParent, where TC is a
        %   prodserver.mcp.internal.TraceContext: an invalid one leaves the
        %   field out. TC may instead be a function handle that returns a
        %   TraceContext; it is called at most once per request, when the
        %   first line that needs the field is written, and a handle that
        %   raises, or returns an invalid context, leaves the field out. The
        %   two options are independent: either can be set without clearing
        %   the other. An unknown option is ignored.

        % Contract:
        %   Kind:      command (fields only; no I/O)
        %   Requires:  none (any input)
        %   Ensures:   later lines of this request carry the field; a handle is not called here
        %   Raises:    none
            try
                for k = 1:2:numel(varargin) - 1
                    switch lower(string(varargin{k}))
                        case "tool"
                            obj.Tool = prodserver.mcp.protocol.echo(varargin{k+1}, quoted=false);
                            if ~prodserver.mcp.validation.isTextScalar(varargin{k+1})
                                obj.Tool = "";
                            end
                        case "trace"
                            tc = varargin{k+1};
                            if isa(tc, "function_handle")
                                obj.Trace = tc;
                            else
                                obj.Trace = prodserver.mcp.logging.Log.traceText(tc);
                            end
                    end
                end
            catch
                % Logging never raises.
            end
        end

        function lvl = level(obj)
        %level The threshold. Callers that build a costly message test it
        %   with an ordering: if level(log) <= Level.Trace.
            lvl = obj.Threshold;
        end
    end

    methods (Static)
        function obj = instance(varargin)
        %instance The archive's Log, made on first use.
        %   instance() reads main_config once and keeps the Log in
        %   archiveCache. instance(action="clear") drops it, so the next call
        %   reads main_config again and forgets logOnce's keys. A call with
        %   no arguments, every request's, is one archiveCache lookup; it has
        %   no arguments block for that reason.

        % Contract:
        %   Kind:      command (reads main_config on first use)
        %   Requires:  none
        %   Ensures:   obj is this archive's one Log until "clear"
        %              a bad --log-severity gives Threshold Information and one
        %              LogSeverityUnavailable line
        %   Raises:    none
            if nargin == 0
                obj = prodserver.mcp.handler.archiveCache(prodserver.mcp.logging.Log.CacheName);
                if ~isempty(obj)
                    return
                end
            end
            obj = prodserver.mcp.logging.Log.makeOrClear(varargin{:});
        end
    end

    methods (Access = private)
        function throttle(obj, key, interval, lvl, id, fmt, args)
        % logOnce and logOncePer: log, unless KEY's last line is younger than INTERVAL.
            try
                if ~(isnumeric(interval) && isscalar(interval) && isreal(interval) && ...
                        interval >= 0)
                    interval = Inf;
                end
                key = string(key);
                t = posixtime(datetime("now", TimeZone="UTC"));
                if isKey(obj.Seen, key) && t - obj.Seen(key) < interval
                    return
                end
                obj.Seen(key) = t;
                obj.log(lvl, id, fmt, args{:});
            catch
                % Logging never raises.
            end
        end

        function line = format(obj, lvl, id, fmt, args)
            % One bounded token, whatever ID is: never string(id) first,
            % which raises for a struct and would drop the line.
            id = prodserver.mcp.protocol.echo(id, quoted=false);
            try
                msg = string(sprintf(fmt, args{:}));
            catch
                msg = string(fmt);
            end
            if isa(obj.Trace, "function_handle")
                handle = obj.Trace;
                obj.Trace = "";             % called at most once, even if it raises
                try
                    obj.Trace = prodserver.mcp.logging.Log.traceText(handle());
                catch
                end
            end
            fields = ["id=" + obj.Id, "trace=" + obj.Trace, "archive=" + obj.Archive, ...
                "tool=" + obj.Tool];
            fields = fields([obj.Id, obj.Trace, obj.Archive, obj.Tool] ~= "");
            head = "[mcp:" + lower(string(lvl)) + "] " + id;
            if ~isempty(fields)
                head = head + " " + join(fields, " ");
            end
            line = head + " " + prodserver.mcp.internal.escapeControl(msg);
        end

        function readThreshold(obj, instanceRoot)
        % The threshold from main_config, and the line when it can't be read.
            import prodserver.mcp.logging.Level
            obj.Threshold = Level.Information;
            if strlength(instanceRoot) == 0
                return
            end
            file = fullfile(instanceRoot, "config", "main_config");
            value = missing;
            try
                lines = strip(splitlines(string(fileread(file))));
                lines = lines(startsWith(lines, "--log-severity"));
                if ~isempty(lines)
                    value = strip(extractAfter(lines(end), "--log-severity"));
                end
            catch
            end
            names = string(enumeration("prodserver.mcp.logging.Level"));
            k = find(strcmpi(names, value), 1);
            if isempty(k)
                obj.log(Level.Warning, prodserver.mcp.logging.Event.LogSeverityUnavailable, ...
                    "%s has no usable --log-severity (%s); using information.", ...
                    file, prodserver.mcp.protocol.echo(value));
                return
            end
            obj.Threshold = Level(names(k));
        end
    end

    methods (Static, Access = private)
        function obj = makeOrClear(varargin)
        % instance's slow path: make the Log, or drop it.
            import prodserver.mcp.handler.archiveCache
            name = prodserver.mcp.logging.Log.CacheName;
            obj = [];
            try
                if nargin >= 2 && strcmpi(string(varargin{1}), "action") && ...
                        strcmpi(string(varargin{2}), "clear")
                    archiveCache(name, action="clear");
                    return
                end
                obj = archiveCache(name);
                if isempty(obj)
                    obj = prodserver.mcp.logging.Log();
                    archiveCache(name, action="set", value=obj);
                end
            catch
                if isempty(obj)
                    obj = prodserver.mcp.logging.Log(instanceRoot="", archive="");
                end
            end
        end

        function text = traceText(tc)
        % The trace= field of a TraceContext: its TraceParent when valid, else "".
            text = "";
            try
                if ~isempty(tc) && isscalar(tc) && tc.IsValid
                    text = prodserver.mcp.protocol.echo(string(tc.TraceParent), quoted=false);
                end
            catch
            end
        end
    end
end
