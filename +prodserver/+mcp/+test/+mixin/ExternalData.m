classdef ExternalData < handle
% ExternalData Mixin for testing with external data. Must be a handle class
% because matlab.unittest.TestCase is.
            
% Copyright 2025, The MathWorks, Inc.
    properties
        marshaller
        removeable
    end

    methods
        function edm = ExternalData
            edm.marshaller = prodserver.mcp.io.MarshallURI();
        end

        function [url,pth] = locate(mix,name,prefix,opts)
        % locate Generate path and full URL for external data source or
        % sink.
            arguments
                mix prodserver.mcp.test.mixin.ExternalData
                name string 
                prefix string 
                opts.ext string = "mat"
                opts.scheme string = "file";
                opts.authority string = "//";
                opts.remove = true;
            end

            pth = fullfile(prefix,name+"."+opts.ext);
            pth = replace(pth,filesep,"/");
            url = opts.scheme+":"+opts.authority+pth;
            url = replace(url,filesep,"/");
            if opts.remove
                mix.removeable = unique([mix.removeable, url]);
            end
        end

        function url = stow(mix,pth,name,data,opts)
            arguments
                mix prodserver.mcp.test.mixin.ExternalData
                pth string
                name string
                data
                opts.ext string = "mat"
                opts.suffix = "Data"
                opts.remove = true;
            end
            [url,file] = locate(mix,name+opts.suffix,pth);
            % Possibly register file for removal when mixin is destroyed.
            if opts.remove
                mix.removeable = unique([mix.removeable, url]);
            end
            
            switch(opts.ext)
                case "mat"
                    save(file,"data");
                otherwise
                    if istable(data)
                        writetable(data,file);
                    else
                        writematrix(data,file);
                    end
            end
        end

        function x = fetch(mix,source,opts)
        % fetch Deserialize data from source according to importer. 

            % Copyright 2025, The MathWorks, Inc.

            arguments
                mix prodserver.mcp.test.mixin.ExternalData
                source (1,1) string
                opts.import {prodserver.mcp.validation.mustBeImportOptions} = []
            end

            x = deserialize(mix.marshaller,source,import=opts.import);
            x = x{1};  % Always a cell array, actual value in element 1.
        end

        function delete(mix)
            % Delete resources registered for removal.
            for n = 1:numel(mix.removeable)
                u = prodserver.mcp.io.parseURI(mix.removeable(n));
                switch u.scheme
                    case "file"
                        if exist(u.path,"file") == 2
                            delete(u.path);
                        end
                    case "http"
                        % Send a DELETE to the resource
                end
            end
        end

    end
end
