function [envConfig,noiseScale] = condition(d,base,factor,shift)
% CONDITION The registered protocol-v2 cell (one factor changed) for a run or reference config.
base.evaluation = d.c.evaluation;
[envConfig,noiseScale] = landing2d.minimal.generalizationCondition(base,factor,shift);
end
