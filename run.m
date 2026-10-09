function output = run(options)
% RUN  Complete scratch-training, validation, and visualization pipeline.
%   run(struct('spatialDimension',3))   % 3D option (lateral y + roll), results/spatial3d
%   run(struct('latestOntology',true))  % latest saved ontology evidence only
if nargin < 1, options=struct(); end
root=fileparts(mfilename('fullpath'));
sourceRoots={fullfile(root,'src','orchestration'), ...
    fullfile(root,'src','simulations'),fullfile(root,'src','algorithms')};
for i=1:numel(sourceRoots)
    if ~contains([path pathsep],[sourceRoots{i} pathsep])
        addpath(sourceRoots{i});
    end
end
output=landing2d.orchestration.runPipeline(options);
if nargout==0, assignin('base','landingStudy',output); end
end
