function text = descriptionText(lines, stage)
%descriptionText A parameter's published description from its comment.
%   text = descriptionText(lines, stage) joins the comment LINES with
%   newlines: the MCP protocol wants one string, but line breaks are fine.
%   At the Definition stage, %#schema lines are left out; they are
%   build-time pragmas, not description. (At the Wrapper stage they stay,
%   for the generated wrapper's comments.) Both schema paths use this.

% Copyright 2026 The MathWorks, Inc.

    if stage == prodserver.mcp.BuildStage.Definition
        lines = lines(~startsWith(lines, prodserver.mcp.internal.Constants.Schema));
    end
    text = strjoin(lines, newline);
end
