classdef tWorkflow < prodserver.mcp.test.base.MCPCaller & ...
        prodserver.mcp.test.mixin.ExternalData

% Copyright 2026 The MathWorks, Inc.

    methods (TestMethodSetup)
        function scratchSpace(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            % Temporary folder for intermediate / generated artifacts
            tfolder = TemporaryFolderFixture;
            applyFixture(test,tfolder);
            setFolders(test,temp=tfolder.Folder);
        end
    end

    methods(Test)

        function vanilla(test)
        % Main line, ordinary workflow. Deploy and call a simple tool.

            fcn = "toyToolOne";
            archive = "workflow";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,archive));

            % Expected result
            a = 3; b = 17;
            [eX,eY,eZ] = feval(fcn,a,b);

            % Build tool
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive);
            test.verifyEqual(exist(ctf,"file"),2,ctf);

            % Deploy
            endpoint = prodserver.mcp.deploy(ctf,test.host,test.port);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                % Validate
                tf = prodserver.mcp.exist(endpoint,fcn,"Tool",protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " is not a tool at " + endpoint + " [" + p + "]");

                % Create the file URL inputs in the temporary folder.
                xURL = sink(test,"x",test.tempFolder);
                yURL = sink(test,"y",test.tempFolder);
                zURL = sink(test,"z",test.tempFolder);
                bURL = stow(test,test.tempFolder,"b",b);

                % Invoke - x,y,z and b are externalized.
                prodserver.mcp.call(endpoint,fcn,a,bURL,xURL=xURL,...
                    yURL=yURL,zURL=zURL);

                % Fetch outputs from their URLs.
                aX = fetch(test,xURL);
                aY = fetch(test,yURL);
                aZ = fetch(test,zURL);

                test.verifyEqual(aX,eX,"x [" + p + "]");
                test.verifyEqual(aY,eY,"y [" + p + "]");
                test.verifyEqual(aZ,eZ,"z [" + p + "]");
            end

            % Validate metrics (protocol-independent, run once after all
            % protocol iterations)
            nProtocols = numel(test.Protocols);

            serverMetrics = prodserver.mcp.MCPConstants.MCPMetricPrefix + ...
                archive + prodserver.mcp.MCPConstants.MCPMetricSuffix;
            catalog = prodserver.mcp.metrics(endpoint);

            % Non-zero server request count
            sm = name(catalog,serverMetrics);
            test.verifyGreaterThan(sum([sm.value]),0);

            % Server request count less than or equal to framework request
            % count.
            frm = name(catalog,prodserver.mcp.MCPConstants.MCPRequestMetric);
            test.verifyTrue(sum([sm.value]) <= sum([frm.value]), ...
                "Server metric > Request metric");

            % Tools call count exactly equal to nProtocols -- one call per
            % protocol iteration. May be multiple metrics from older
            % versions of this archive.
            toolCallMetric = prodserver.mcp.MCPConstants.MCPMetricPrefix + ...
                fcn + prodserver.mcp.MCPConstants.MCPToolCallSuffix;
            tcm = catalog.archive(archive,suffix=@max);
            test.assertNotEmpty(tcm,"No metrics for " + archive);

            % If all suffixes are [], sfx will be all NaN
            sfx = unique(arrayfun(@(m)str2double(m.suffix),tcm));
            if all(isnan(sfx))
                tcm = catalog.filter(name=toolCallMetric,archive=archive,...
                    suffix=NaN);
            else
                % There should be only one maximum suffix.
                test.verifyNumElements(sfx,1,"Ambiguous archive suffix");
                tcm = catalog.filter(name=toolCallMetric,archive=archive, ...
                    suffix=sfx);
            end

            test.assertGreaterThan(numel(tcm),0,"Zero metrics for archive " + ...
                archive);
            test.verifyEqual(tcm.archive,archive,"Wrong archive: " + tcm.archive);
            
            for n=1:numel(tcm)
                test.verifyEqual(tcm(n).value, nProtocols, ...
                    tcm(n).archive+tcm(n).suffix);
            end

        end

    end
end
