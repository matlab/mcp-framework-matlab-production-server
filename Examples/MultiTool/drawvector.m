function drawvector(bbox, vectors, width, height, jpg)
% DRAWVECTOR Turtle Graphics for MATLAB. 
%
% The input vector list specifies a vector path. The end point of vector N is
% the origin of vector N+1. Draw the vector path, and then draw the bounding
% box.
%
% Example:
%
%    [vectors,bbox] = snowflake(4,300,300);
%    drawvector(bbox, vectors,);

% Copyright 2025, The MathWorks

    arguments(Input)
        bbox double % Bounding box that contains the vectors
        vectors double % Turtle graphics vectors
        width (1,1) double % Width of the JPG image, in pixels.
        height (1,1) double % Height of the JPG image, in pixels.
        jpg (1,1) string % Full path to the JPG image file in which to save the image.
    end

    f=figure('Position', [0,0,width,height], Color='white', Visible="off");
    point = zeros(1,2,class(vectors));
    rows = size(vectors, 1);
    for k = 1:rows
        next = point + vectors(k,:);
        line([point(1), next(1)], [point(2), next(2)], Color="red");
        point = next;
    end
    
    x = bbox(1);
    y = bbox(2);
    w = bbox(3);
    h = bbox(4);
    
    % Draw bounding box
    line([x,x],[y,y+h]);       % Left
    line([x,x+w], [y+h,y+h]);  % Top
    line([x+w,x+w], [y+h,y]);  % Right
    line([x+w,x],[y,y]);       % Bottom
    
    axis off
    axis equal

    % exportgraphics has been known to crash the server.
    saveas(f,jpg);
end
