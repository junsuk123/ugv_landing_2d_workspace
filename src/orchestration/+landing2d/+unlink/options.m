function o=options(in)
% OPTIONS Fixed intervention schedule, not selected by observed performance.
if nargin<1, in=struct(); end
root=landing2d.orchestration.projectRoot();
o=struct('scenarioId','S1','seed',[],'trainSeed',1,'sensorNoiseScale',1, ...
    'cutStart',5,'cutDuration',3,'figureVisible',true,'saveResults',true, ...
    'checkpointDir',fullfile(root,'results'), ...
    'outputDir',fullfile(root,'results','unlink'));
assert(isstruct(in)&&isscalar(in),'landing2d:UnlinkOptions','Options must be a scalar struct.');
for name=string(fieldnames(in))'
    assert(isfield(o,name),'landing2d:UnlinkOptions','Unknown option: %s',name);
    o.(name)=in.(name);
end
o.scenarioId=validatestring(upper(char(o.scenarioId)),{'S1','S2','S3'});
validateattributes(o.cutStart,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(o.cutDuration,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(o.sensorNoiseScale,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(o.trainSeed,{'numeric'},{'scalar','integer','positive','finite'});
if ~isempty(o.seed), validateattributes(o.seed,{'numeric'},{'scalar','integer','nonnegative','finite'}); end
for name=["figureVisible","saveResults"]
    validateattributes(o.(name),{'numeric','logical'},{'scalar','binary'}); o.(name)=logical(o.(name));
end
for name=["checkpointDir","outputDir"]
    assert(ischar(o.(name)) || (isstring(o.(name))&&isscalar(o.(name))), ...
        'landing2d:UnlinkOptions','%s must be a path.',name);
    o.(name)=char(o.(name)); assert(~isempty(o.(name)),'landing2d:UnlinkOptions','Paths cannot be empty.');
end
end
