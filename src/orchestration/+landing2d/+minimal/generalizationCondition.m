function [c,noiseScale] = generalizationCondition(c,factor,shift)
% GENERALIZATIONCONDITION Matched reference: change ONE numerical factor.
% Motion references both force CA. Dropout references both force severe
% dropout. Thus changing the occurrence probability is not an OOD effect.
assert(ismember(shift,{'ID','OOD'}),'landing2d:GeneralizationShift','Use ID or OOD.');
g = c.evaluation.generalization;
noiseScale = 1;
switch factor
    case 'motion'
        c.experiment.scenario.constantVelocityProbability = 0;
        if strcmp(shift,'OOD'), c.experiment.scenario.a2Range = g.oodA2Range; end
    case 'dropout'
        c.experiment.sensor.perturbation.cleanProbability = 0;
        c.experiment.sensor.perturbation.mildDropoutProbability = 0;
        if strcmp(shift,'OOD')
            c.experiment.sensor.perturbation.severeDropoutDuration = g.oodDropoutDuration;
        end
    case 'noise'
        if strcmp(shift,'OOD'), noiseScale = g.oodNoiseScale; end
    otherwise
        error('landing2d:GeneralizationFactor','Unknown factor %s.',factor);
end
end
