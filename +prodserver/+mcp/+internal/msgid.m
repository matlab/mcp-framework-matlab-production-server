function id = msgid(id)
%msgid Return the full message identifier. Add message catalog root to a 
%message id. Allows catalog to move to a new root easily.

% Copyright 2025, The MathWorks, Inc.
  
  id = "prodserver:mcp:" + id;
end
