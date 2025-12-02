function sz = renderDragon(dragon, color1, color2, jpg)
% renderDragon Generate a JPEG image of the twin-dragon fractal.
    arguments(Input)
        dragon double % Coordinates of the twin-dragon's points.
        % Color of the first of the twin dragons. A six-digit hexadecimal
        % number, as a string.
        color1 (1,1) string 
        % Color of the first of the twin dragons. A six-digit hexadecimal
        % number, as a string.
        color2 (1,1) string 
        jpg (1,1) string   % Path to output JPEG file.
    end
    arguments(Output)
        % Bounding box of the JPEG image: [left, bottom, width, height].
        % The "OuterPosition" of the MATLAB figure used to render the
        % image.
        sz double 
    end

    f = figure(Visible="off",Color="white");
    derez = onCleanup(@()close(f));
    color1 = hex2rgb(color1);
    color2 = hex2rgb(color2);

    hold on
    scatter(dragon(1, 2:2:end),dragon(2, 2:2:end), SizeData=0.1, ...
        Marker='.', MarkerEdgeColor=color1);
    
    scatter(dragon(1, 1:2:end-1),dragon(2, 1:2:end-1), SizeData=0.1, ...
        Marker='.', MarkerEdgeColor=color2);
    
    axis off 
    axis equal

    drawnow

    sz = get(f,"OuterPosition");
    
    % Crashes the worker
    %exportgraphics(f, file);
    saveas(f,jpg,"jpg");

end

