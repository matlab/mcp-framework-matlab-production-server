classdef ExternalData < handle
% ExternalData Mixin for testing with external data. Must be a handle class
% because matlab.unittest.TestCase is.
            
% Copyright 2025, The MathWorks, Inc.
    properties
        marshaller
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
            end

            pth = fullfile(prefix,name+"."+opts.ext);
            pth = replace(pth,filesep,"/");
            url = opts.scheme+":"+pth;
            url = replace(url,filesep,"/");
        end

        function url = stow(mix,pth,name,data,opts)
            arguments
                mix prodserver.mcp.test.mixin.ExternalData
                pth string
                name string
                data
                opts.ext string = "mat"
                opts.suffix = "Data"
            end
            [url,file] = locate(mix,name+opts.suffix,pth);
            
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

    end
end
