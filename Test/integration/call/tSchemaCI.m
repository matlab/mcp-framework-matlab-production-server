classdef tSchemaCI < MCPCaller & ...
        prodserver.mcp.test.mixin.ExternalData

    methods (TestMethodSetup)
        function scratchSpace(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            % Temporary folder for intermediate / generated artifacts
            tfolder = TemporaryFolderFixture;
            applyFixture(test,tfolder);
            test.tempFolder = tfolder.Folder;
        end

    end

    methods(Test)

        function literal(test)
      
            import prodserver.mcp.internal.hasField

            % Requires parameter-focused test tools
            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireParamTools());
            test.toolFolder = rtt.toolFolder;

            % Generate wrapper for a function that uses a client-written
            % schema.
            fcn = "literalSchemas";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,fcn));

            % Build 
            ctf = prodserver.mcp.build(fcn,folder=test.tempFolder);

            % Deploy
            endpoint = prodserver.mcp.deploy(ctf,test.host,test.port);

            % Get the description from the server and ensure the schemas
            % match.
            d = prodserver.mcp.list(endpoint,"Tool");

            % At least two tools on every server -- the user-specified tool
            % and read_mcp_resource.
            names = cellfun(@(t)string(t.name),d);
            found = strcmp(fcn,names);
            test.verifyEqual(nnz(found),1,"Too many tools named " + fcn);
                
            % Extract the tool definition structure.
            d = d{found};

            % Retrieved schemas must match original schemas.
            cSchema = d.inputSchema.properties.circle;
            cSchema = rmfield(cSchema,"description");
            expectedSchema = jsondecode(...
                fileread(fullfile(test.toolFolder,"circle.json")));
            expectedSchema.maxItems = 11;

            % Expect annotation field to match default encoding
            test.verifyTrue(hasField(cSchema,"annotation"), "Annotation missing");
            test.verifyTrue(startsWith(cSchema.annotation,"Invertible wire encoding wrapper"), ...
                "Incorrect annotation");

            test.verifyTrue(hasField(cSchema,"properties.data"), ...
                "Missing properties.data");

            test.verifyEqual(cSchema.properties.data,expectedSchema,"Circle schemas not equal");

            sSchema = d.inputSchema.properties.square;
            sSchema = rmfield(sSchema,"description");
            expectedSchema = jsondecode(...
                fileread(fullfile(test.toolFolder,"square.json")));
            expectedSchema.maxItems = 13;

            % Expect annotation field to match default encoding
            test.verifyTrue(hasField(sSchema,"annotation"), "Annotation missing");
            test.verifyTrue(startsWith(sSchema.annotation,"Invertible wire encoding wrapper"), ...
                "Incorrect annotation");

            test.verifyTrue(hasField(sSchema,"properties.data"), ...
                "Missing properties.data");


            test.verifyEqual(sSchema.properties.data,expectedSchema,"Square schemas not equal");

            % Make up some data and then call the deployed function
            xC = num2cell(randi(100,[11,1]));
            yC = num2cell(randi(100,[11,1]));
            originC = struct("x", xC, "y", yC);
            radius = num2cell(randperm(11))';
            circle = struct("origin", originC, "radius", radius);

            xS = num2cell(randi(100,[13,1]));
            yS = num2cell(randi(100,[13,1]));
            originS = struct("x", xS, "y", yS);
            side = num2cell(randperm(13))';
            square = struct("side", side, "origin", originS);

            [a.sortedC, a.sortedS, a.areaC, a.areaS] = literalSchemas(...
                circle, square);
            [e.sortedC, e.sortedS, e.areaC, e.areaS] = ...
                prodserver.mcp.call(endpoint,fcn,circle, square);
            test.verifyEqual(a,e,"Something went wrong");
            test.verifyEqual([a.sortedC.radius],1:11,"Circle sort order wrong");
            test.verifyEqual([a.sortedS.side],1:13,"Side sort order wrong");
        end


        function wrappedFileSchema(test)
            import prodserver.mcp.MCPConstants

            % Many optional arguments
            fcn = "toyFileSchema";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,fcn));

            % Build -- suppress wrapper generation for this example to test
            % structure transmission over JSON.
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder);
            
            test.verifyEqual(exist(ctf,"file"),2,ctf);

            % Deploy
            endpoint = prodserver.mcp.deploy(ctf,test.host,test.port);

            % Get the expected value
            m = 11; r.x = 3; r.y = 4; r.z = 5;
            [eZ,eQ] = feval(fcn,m,r);

            % Allocate space for the input and output
            aZURI = locate(test,"Z",test.tempFolder);
            rURI = stow(test,test.tempFolder,"R",r);

            % Call the function on the server.
            aQ = prodserver.mcp.call(endpoint,fcn,m,rURI,zURL=aZURI);
            aZ = fetch(test,aZURI);
            test.verifyEqual(aZ,eZ,"Z");
            test.verifyEqual(aQ,eQ,"Q");

        end

        function noWrapperUserSchema(test)
            import prodserver.mcp.MCPConstants

            % Requires parameter-focused test tools
            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireParamTools());
            test.toolFolder = rtt.toolFolder;

            % Many optional arguments
            fcn = "fixedSizeVectors";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server,fcn));

            % Build 
            ctf = prodserver.mcp.build(fcn,folder=test.tempFolder, ...
                wrapper="None");

            % Deploy
            endpoint = prodserver.mcp.deploy(ctf,test.host,test.port);

            % Generate circles and squares with area less than 11
            %
            % Going from high to low index allocates the entire structure
            % on the first call and avoids the growth warning.
            for k = 11:-1:1
                circle(k).radius   = sqrt(k / pi);
                circle(k).origin.x = k;
                circle(k).origin.y = randi(11);
            end
            circle = circle(randperm(numel(circle)));

            for k = 7:-1:1
                square(k).side = sqrt(k);
                square(k).origin.x = randi(7);
                square(k).origin.y = randi(7);
            end
            square = square(randperm(numel(square)));

            % All objects with area < 4.5. 
            area = 4.5;
            cA = arrayfun(@(c)c.radius * c.radius * pi, circle);
            sA = arrayfun(@(s)s.side * s.side,square);
            eS = square(sA < area);
            eC = circle(cA < area);
            eList = [num2cell(eC), num2cell(eS)];

            % Call -- transmit all data over the wire
            list = prodserver.mcp.call(endpoint,fcn,circle,square,area);
            test.verifyEqual(numel(list),numel(eList),"Result length");
            test.verifyEqual(list,eList,"Result list");
        end
    end
end

