function tf = isSandbox()
% isSandbox Running in sandbox mode?

% Copyright 2025, The MathWorks, Inc.

    ml = string(filesep)+"matlab"+textBoundary("end");
    root = erase(matlabroot,ml);
    files = ["mw_anchor", "job-info"];
    pth = fullfile(root,files);
    tf = all(arrayfun(@(f)exist(f,"file")==2,pth));
end
