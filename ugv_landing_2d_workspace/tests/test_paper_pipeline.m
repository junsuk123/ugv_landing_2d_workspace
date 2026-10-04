function test_paper_pipeline()
% TEST_PAPER_PIPELINE  Fixed scenario injection and metric audit smoke test.
root=fileparts(fileparts(mfilename('fullpath')));
c=landing2d.config.primaryConfig(root);
specs=landing2d.paper.representativeScenarios(c);
assert(numel(specs)==3);
assert(all(arrayfun(@(x)landing2d.paper.scenarioFeasibility(x,c).PhysicalFeasible, ...
    specs)));
assert(strcmp(specs(3).sensorEvents.dropoutKind,'short'));
assert(abs(specs(3).sensorEvents.dropoutEnd-specs(3).sensorEvents.dropoutStart-0.8)<1e-12);

arm=landing2d.graphstate.applyStateRepresentation(c,'baseline');
rs=RandStream('threefry','Seed',73);
agent=landing2d.rl.agentInit(arm.rl,rs,arm.graphState);
opts=struct('deterministic',true,'scenario',specs(3).scenario, ...
    'sensorEvents',specs(3).sensorEvents,'maxDecisions',8);
[result,traj]=landing2d.rl.rolloutEpisodeV2(agent,arm,specs(3).seed,opts);
assert(abs(result.scenario.v3-specs(3).scenario.v3)<1e-12);
assert(strcmp(result.resetInfo.evaluatorMetadata.sensorEvents.dropoutKind,'short'));
metric=landing2d.paper.trajectoryMetrics(result,traj,specs(3),c, ...
    'test baseline','baseline');
assert(isfinite(metric.StabilityIndex) && metric.StabilityIndex>=0 ...
    && metric.StabilityIndex<=100);
assert(metric.PhysicalFeasible);
assert(strlength(metric.Interpretation)>0);
end
