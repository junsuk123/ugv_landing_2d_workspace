function [c,noiseScale] = condition(c,factor,shift)
% CONDITION Numerical shifts with matched occurrence probabilities.
assert(ismember(shift,{'ID','OOD'}),'landing2d:CurrentSemanticsShift','Use ID or OOD.');
g = c.evaluation.generalization;
assert(ismember(factor,g.conditions),'landing2d:CurrentSemanticsFactor','Unknown factor.');
noiseScale = 1;
if ismember(factor,{'motion','combined'})
    c.experiment.scenario.constantVelocityProbability = 0;
    if strcmp(shift,'OOD'), c.experiment.scenario.a2Range = g.oodA2Range; end
end
if ismember(factor,{'dropout','combined'})
    c.experiment.sensor.perturbation.cleanProbability = 0;
    c.experiment.sensor.perturbation.mildDropoutProbability = 0;
    if strcmp(shift,'OOD')
        c.experiment.sensor.perturbation.severeDropoutDuration = g.oodDropoutDuration;
    end
end
if ismember(factor,{'noise','combined'}) && strcmp(shift,'OOD')
    noiseScale = g.oodNoiseScale;
end
end
