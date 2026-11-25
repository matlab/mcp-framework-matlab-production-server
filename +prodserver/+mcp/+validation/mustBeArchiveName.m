function mustBeArchiveName(name, file)
% mustBeArchiveName Error unless NAME is an archive name the framework can
% use: one or more ASCII letters, digits and '_', and not Framework, which
% the framework's own request metric uses (MCP_Framework_Request).
%
%   mustBeArchiveName(name) checks each element of NAME.
%
%   mustBeArchiveName(name, file) says, as well, that NAME is the base name
%   of FILE, so the fix is to rename the file.
%
%   The archive name is the CTF file's base name, the first segment of the
%   endpoint's path (/<archive>/mcp), the ctf= query parameter of the upload
%   and a label on the server's metrics. Other characters fail in one of
%   those places, deep in matlab.net.http, with an error that doesn't name
%   the archive. A hyphen fails earlier, in MATLAB Compiler: as of R2026b,
%   compiler.build.productionServerArchive refuses ArchiveName="add-one"
%   with Compiler:compiler:COM_ERR_BAD_WRAPPER_SYNTAX ("The -W option
%   ("CTF:add-one") is not correctly formed"). The documentation states no
%   rule, so check this if a later release allows it. A leading digit is
%   fine.

% Copyright 2026 The MathWorks, Inc.

    arguments
        name string
        file string = string.empty
    end

    for n = name(:)'
        if ismissing(n) || isempty(regexp(n, '^[A-Za-z0-9_]+$', 'once'))
            msg = sprintf("Archive name '%s' isn't allowed. Archive " + ...
                "names may contain only letters (A-Z, a-z), digits and " + ...
                "'_', not '-' or other characters.", n);
            if ~isempty(file)
                msg = msg + sprintf(" The archive name is the file " + ...
                    "name of %s: rename the file.", file);
            end
            throwAsCaller(MException("prodserver:mcp:InvalidArchiveName", ...
                "%s", msg));
        end
        % Reserved: the framework counts every request in a metric named as
        % if for this archive, and MPS would add the archive's own request
        % counter into it, so neither could be read.
        reserved = prodserver.mcp.MCPConstants.MCPFrameworkMetricName;
        if n == reserved
            msg = sprintf("Archive name '%s' is reserved. The MCP " + ...
                "framework counts every request in the metric %s, and " + ...
                "an archive of that name would count its own requests in " + ...
                "the same metric. Choose another name.", n, ...
                prodserver.mcp.MCPConstants.MCPRequestMetric);
            if ~isempty(file)
                msg = msg + sprintf(" The archive name is the file " + ...
                    "name of %s: rename the file.", file);
            end
            throwAsCaller(MException("prodserver:mcp:InvalidArchiveName", ...
                "%s", msg));
        end
    end
end
