classdef BuildStage
% BuildStage Stages of the build process. An ordered list.

% Copyright 2025, The MathWorks, Inc.

    properties (Constant)
        % The order of the build stages. See prodserver.mcp.build.
        Order = [ prodserver.mcp.BuildStage.Wrapper,...
                  prodserver.mcp.BuildStage.Definition,...
                  prodserver.mcp.BuildStage.Routes,...
                  prodserver.mcp.BuildStage.Archive, ...
                  prodserver.mcp.BuildStage.Deploy ]
    end

    enumeration
        Wrapper      % Prepare tool wrapper functions.
        Definition   % Generate tool definitions.
        Routes       % Modify boiler plate routes files for this server.
        Archive      % Create deployable CTF archive.
        Deploy       % Deploy archive to server.
    end

    methods
        %
        % Relational operators allow position comparison.
        % 
        
        function tf = lt(s0,s1)
        %lt Does s0 occur before s1 in the BuildStage order?

            arguments
                s0 prodserver.mcp.BuildStage
                s1 prodserver.mcp.BuildStage
            end

            % Compare numeric offsets.
            [~,p0] = ismember(s0,prodserver.mcp.BuildStage.Order);
            [~,p1] = ismember(s1,prodserver.mcp.BuildStage.Order);
            tf = p0 < p1;
        end

        function tf = gt(s0,s1)
        %gt Does s0 occur after s1 in the BuildStage order?

            arguments
                s0 prodserver.mcp.BuildStage
                s1 prodserver.mcp.BuildStage
            end

            lessThan = s0 < s1;
            equalTo = s0 == s1;
            tf = ~lessThan & ~equalTo;
        end

        function tf = ge(s0,s1)
        %ge Does s0 occur after or at the same place as s1 in the 
        % BuildStage order?

            arguments
                s0 prodserver.mcp.BuildStage
                s1 prodserver.mcp.BuildStage
            end

            greaterThan = s0 > s1;
            equalTo = s0 == s1;
            tf = greaterThan | equalTo;
        end

        function tf = le(s0,s1)
        %le Does s0 occur before or at the same place as s1 in the 
        % BuildStage order?
        
            arguments
                s0 prodserver.mcp.BuildStage
                s1 prodserver.mcp.BuildStage
            end

            lessThan = s0 < s1;
            equalTo = s0 == s1;
            tf = lessThan | equalTo;
        end

    end

end