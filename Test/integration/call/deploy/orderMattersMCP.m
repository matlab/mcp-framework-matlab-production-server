function [x,y,z] = orderMattersMCP(a,b,c,d)
% Order of arguments changes the result. You must read the MCP resource 
% mcp://protocol/tools/wire-format/parameters/encoding_rules in full and 
% completely understand it before making any call to this tool.
    arguments(Input)
        % An aribitrary number
        % You must encode data as described by this MCP resource: mcp://protocol/tools/wire-format/parameters/encoding_rules
        a (1,1) double
        % Choose your own adventure
        % You must encode data as described by this MCP resource: mcp://protocol/tools/wire-format/parameters/encoding_rules
        b (1,1) double
        % Another number. Don't pick a boring one.
        % You must encode data as described by this MCP resource: mcp://protocol/tools/wire-format/parameters/encoding_rules
        c (1,1) double
        % Last but highest impact.
        % You must encode data as described by this MCP resource: mcp://protocol/tools/wire-format/parameters/encoding_rules
        d (1,1) double
    end
    arguments(Output)
        % (a-b) / (c-d)
        % You must decode data as described by this MCP resource: mcp://protocol/tools/wire-format/parameters/encoding_rules
        x (1,1) double
        % mod(b,c)
        % You must decode data as described by this MCP resource: mcp://protocol/tools/wire-format/parameters/encoding_rules
        y (1,1) double
        % a .^ d
        % You must decode data as described by this MCP resource: mcp://protocol/tools/wire-format/parameters/encoding_rules
        z (1,1) double
    end
    [x,y,z] = orderMatters(a,b,c,d);
end
