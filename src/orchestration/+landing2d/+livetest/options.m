function o = options(in)
% OPTIONS Interactive diagnostic settings; not training/evaluation defaults.
if nargin<1, in=struct(); end
o=struct('duration',300,'height',5,'initialPadSpeed',1,'seed',2038, ...
    'sensorNoiseScale',1,'mode','hold','controller','onto_rgat_ppo', ...
    'trainSeed',1,'graphSeed',1,'includeShuffled',false,'checkpointDir','', ...
    'playbackSpeed',1,'autoStart',false,'autoReset',true,'figureVisible',true, ...
    'pulseAcceleration',1.5,'pulseDuration',1.2,'pulseCoast',3, ...
    'maxPadSpeed',7.5,'historySeconds',30,'maxRetainedEpisodes',10,'cutDuration',3);
assert(isstruct(in)&&isscalar(in),'landing2d:LiveTestOptions','Options must be a scalar struct.');
for f=string(fieldnames(in))'
    assert(isfield(o,f),'landing2d:LiveTestOptions','Unknown option: %s',f);
    o.(f)=in.(f);
end
for f=["duration","height","playbackSpeed","pulseAcceleration","pulseDuration", ...
        "maxPadSpeed","historySeconds","cutDuration"]
    validateattributes(o.(f),{'numeric'},{'scalar','real','finite','positive'});
end
assert(o.duration>=10 && o.duration<=3600,'landing2d:LiveTestDuration','Use 10–3600 seconds per episode.');
assert(o.height>=1 && o.height<=10,'landing2d:LiveTestHeight','Use 1–10 m initial/hold height.');
assert(o.cutDuration>=.1 && o.cutDuration<=60,'landing2d:LiveTestCutDuration','Use .1–60 s edge cuts.');
validateattributes(o.initialPadSpeed,{'numeric'},{'scalar','real','finite','nonnegative'});
assert(o.initialPadSpeed<o.maxPadSpeed);
assert(ismember(o.playbackSpeed,[.25 .5 1 2 4]),'landing2d:LiveTestSpeed','Use 0.25, 0.5, 1, 2, or 4 playback speed.');
validateattributes(o.sensorNoiseScale,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(o.pulseCoast,{'numeric'},{'scalar','real','finite','nonnegative'});
assert(o.sensorNoiseScale<=5 && o.pulseAcceleration>=.1 && o.pulseAcceleration<=3 ...
    && o.pulseDuration>=.1 && o.pulseDuration<=5 && o.pulseCoast<=20, ...
    'landing2d:LiveTestRange','GUI ranges: noise 0–5, acceleration .1–3, pulse .1–5 s, coast 0–20 s.');
for f=["seed","trainSeed","graphSeed","maxRetainedEpisodes"]
    validateattributes(o.(f),{'numeric'},{'scalar','integer','positive'});
end
o.mode=validatestring(o.mode,{'hold','policy'});
for f=["includeShuffled","autoStart","autoReset","figureVisible"]
    validateattributes(o.(f),{'logical','numeric'},{'scalar','binary'}); o.(f)=logical(o.(f));
end
end
