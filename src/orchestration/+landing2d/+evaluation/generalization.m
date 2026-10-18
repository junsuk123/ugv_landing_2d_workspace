function out = generalization(runs,c)
% GENERALIZATION  Closed-loop evaluation outside the training ranges (stress split).
%   out = landing2d.evaluation.generalization(runs,c)
% Conditions (c.evaluation.generalization), each on the same stress-split
% seeds, so conditions and runs are paired by episode:
%   motion    every episode CV-CA-CV with a2 in oodA2Range (training 0.3-0.8)
%   dropout   one dropout of oodDropoutDuration in every episode (training <= 1 s)
%   noise     sensor-noise standard deviations x oodNoiseScale (training x 1)
%   combined  motion and dropout together
% Only experiment.scenario / sensor.perturbation (and the reset noise scale)
% change; dynamics, reward, termination and policies are untouched. The
% held-out test (landing2d.evaluation.heldOut) is the in-distribution reference.
g = c.evaluation.generalization;
seeds = c.experiment.manifest.stressSeeds(1:g.episodes);
rows = {};
for i = 1:numel(g.conditions)
    name = g.conditions{i};
    for r = 1:numel(runs)
        fprintf('  generalization %-9s %-18s seed %d: %d episodes\n',name, ...
            runs(r).id,runs(r).trainSeed,numel(seeds));
        [envConfig,noiseScale] = conditionConfig(runs(r).config,name,g);
        cases = repmat(struct('scenario',[],'sensorEvents',[],'eventWindow',[], ...
            'sensorNoiseScale',noiseScale),1,numel(seeds));
        identity = repmat(struct('Condition',string(name)),1,numel(seeds));
        rows{end+1} = landing2d.evaluation.rolloutSet(runs(r),envConfig,seeds,cases,identity); %#ok<AGROW>
    end
end
episodes = struct2table([rows{:}]);
metrics = {'Success','Unsafe','Timeout','Return','AimErrorRMS_m','RelativeSpeedRMS_mps', ...
    'CommandRateRMS_mps3','ApproachViewLoss_s','UnsuitableDescent_s'};
R = landing2d.evaluation.runMeans(episodes,{'Condition'},metrics);
out = struct('episodes',episodes,'runs',R, ...
    'summary',landing2d.evaluation.seedSummary(R,{'Condition'},metrics), ...
    'contrasts',landing2d.evaluation.methodContrasts(R,{'Condition'},metrics), ...
    'metrics',{metrics});
end

function [c,noiseScale] = conditionConfig(c,name,g)
noiseScale = [];
s = c.experiment.scenario; p = c.experiment.sensor.perturbation;
if ismember(name,{'motion','combined'})
    s.constantVelocityProbability = 0; s.a2Range = g.oodA2Range;
end
if ismember(name,{'dropout','combined'})
    p.cleanProbability = 0; p.mildDropoutProbability = 0;
    p.severeDropoutDuration = g.oodDropoutDuration;
end
if strcmp(name,'noise'), noiseScale = g.oodNoiseScale; end
c.experiment.scenario = s; c.experiment.sensor.perturbation = p;
end
