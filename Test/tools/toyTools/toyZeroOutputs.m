function toyZeroOutputs(n,exchange,file)
% toyZeroOutputs Generate n UUIDs into file.
    arguments
        n (1,1) double    % Number of UUIDs to generate.
        exchange string   % Replace text in UUID: "old,new".
        file (1,1) string % Path to file in which to store UUIDs.
    end
    
    uuid = strings(1,n);
    for i = 1:n
        uuid(i) = matlab.lang.internal.uuid;
        for x = 1:size(exchange,1)
            uuid(i) = replace(uuid(i),exchange(x,1),exchange(x,2));
        end
    end
    writelines(uuid, file);
end
