function root = projectRoot()
% PROJECTROOT  Resolve the workspace root from the packaged source tree.
root=fileparts(mfilename('fullpath'));
for i=1:4, root=fileparts(root); end
assert(isfolder(fullfile(root,'src')) && isfolder(fullfile(root,'results')), ...
    'landing2d:ProjectRoot','Unable to resolve the workspace root.');
end
