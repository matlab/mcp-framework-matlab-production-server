classdef tExternal < matlab.unittest.TestCase & ...
        prodserver.mcp.test.mixin.ExternalData

% Copyright 2025-2026 The MathWorks, Inc.

    properties
        toolsFolder
        tempFolder
    end

    methods (TestClassSetup)

        function requireTools(test)
            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireParamTools());
            test.toolsFolder = rtt.toolFolder;
        end

        function tempSpace(test)
            % Temporary folder to contain wrappers
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture

            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            test.tempFolder = tFolder.Folder;
            test.applyFixture(PathFixture(test.tempFolder));

        end
    end

    methods (Test)

        function optionalAndExternal(test)
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            % Generate a wrapper for optInExtOut
            tool = "optInExtOut";
            toolMCP = tool+"MCP";
            [code,indirect] = prodserver.mcp.internal.mcpWrapper(tool,toolMCP);
            writelines(code,fullfile(test.tempFolder,toolMCP+".m"));

            % Make sure the wrapper works -- first call the original
            % function to get the expected values.

            q = "a"; v = 1:17;
            p = struct('r', num2cell(1:10)', 'theta', num2cell(21:30)');
            t.r = 7; t.theta = 27;
            [z,u,m] = optInExtOut(q,v,p=p,t=t);
            test.verifyEqual(z,q+v);
            test.verifyEqual(u,sum(strlength(q+v)));
            test.verifyEqual(m,t);
            
            % Now call the MCP function using externalized inputs and
            % outputs.
            urlFolder = string(test.tempFolder);
            zURL = sink(test,"Z",urlFolder);
            mURL = sink(test,"M",urlFolder);

            % Externalize input data
            pURL = stow(test,urlFolder,"P",p);
            tURL = stow(test,urlFolder,"T",t);

            % Mix the order of the optional outputs all around.
            au = optInExtOutMCP(q,v,zURL=zURL,pURL=pURL,mURL=mURL,tURL=tURL);
            az = fetch(test,zURL);
            am = fetch(test,mURL);

            test.verifyEqual(az,z,"Z not equal");
            test.verifyEqual(am,m,"M not equal");
            test.verifyEqual(au,u,"U not equal");

            % Use mcpDefinition to capture metadata about both the original
            % function and the generated wrapper.
            tools = [toolMCP,tool];
            td = prodserver.mcp.internal.defineForMCP(tools,tools,...
                defs={indirect, []});

            % Basic validation
            test.verifyTrue(isstruct(td),"Not a structure");
            test.verifyTrue(isfield(td,"tools"),"tools field missing");
            test.verifyTrue(iscell(td.tools),"tools not a cell array");
            test.verifyEqual(numel(td.tools),numel(tools),...
                "Wrong number of definitions");

            % The outputs Z and M should have been externalized. The inputs
            % P and T are optional. They must appear correctly in the input
            % argument block.
            t = td.tools{1};
            f = td.tools{2};

            test.verifyEqual(t.name,toolMCP);
            test.verifyEqual(f.name,tool);

            % Description of zURL should contain description of z. Remove
            % automatically added WireEncodingOutputMsg, after making sure
            % it too is present.
            
            fzd = f.outputSchema.properties.z.description;

            test.verifyEqual(nnz(contains(fzd,MCPConstants.WireEncodingOutputMsg)),...
                1,"Z WireEncodingOutputMsg missing");

            fzd = erase(fzd,MCPConstants.WireEncodingOutputMsg);
            test.verifyEqual(nnz(contains(t.inputSchema.properties.zURL.description, ...
                fzd)),1,"Z description mismatch");

            % Description of mURL should contain description of m.

            fmd = f.outputSchema.properties.m.description;

            test.verifyEqual(nnz(contains(fmd,MCPConstants.WireEncodingOutputMsg)),...
                1,"M WireEncodingOutputMsg missing");

            fmd = erase(fmd,MCPConstants.WireEncodingOutputMsg);
            test.verifyEqual(nnz(contains(t.inputSchema.properties.mURL.description, ...
                fmd)),1,"M description mismatch");

            % Same for the inputs P and T

            % Description of pURL should contain description of p.
            fpd = f.inputSchema.properties.p.description;
            fpd = erase(fpd,MCPConstants.WireEncodingInputMsg);
            test.verifyEqual(nnz(contains(t.inputSchema.properties.pURL.description, ...
                fpd)), numel(f.inputSchema.properties.p.description),...
                "P description mismatch");

            % Description of tURL should contain description of t.
            ftd = f.inputSchema.properties.t.description;
            ftd = erase(ftd,MCPConstants.WireEncodingInputMsg);
            test.verifyEqual(nnz(contains(t.inputSchema.properties.tURL.description, ...
                ftd)),numel(f.inputSchema.properties.t.description),...
                "T description mismatch");

            % %#schema =polarCoords.json must appear on its own line in
            % the comments of P, T and M.

        end
    end
end