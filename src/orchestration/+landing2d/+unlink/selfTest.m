function report=selfTest(output)
% SELFTEST Pairing, every registered edge, actual action, restoration, plots.
if nargin<1
    output=landing2d.unlink.compare(struct('figureVisible',false,'saveResults',false));
end
s=output.study; normal=s.normal; o=s.options;
c=landing2d.config.primaryConfig(landing2d.orchestration.projectRoot()); c.outputDir=o.checkpointDir;
c=landing2d.config.applyMethod(c,'onto_rgat_ppo',o.trainSeed,1);
[agent,~,file]=landing2d.rl.loadCheckpoint(c); identity=landing2d.rl.runIdentity(agent,c,file);
assert(strcmp(identity.CheckpointHash,s.identity.CheckpointHash));
nEdges=s.graph.nEdges; nNodes=s.graph.nNodes;
assert(numel(s.cases)==nEdges && isequal(s.summary.EdgeId,(1:nEdges)'));
assert(sum(s.graph.src==s.graph.dst)==nNodes);
% The intact implementation reproduces the established rollout exactly.
[reference,traj]=landing2d.rl.rolloutEpisodeV2(agent,c,s.scenario.seed, ...
    struct('deterministic',true,'scenario',s.scenario.scenario, ...
    'sensorEvents',s.scenario.sensorEvents,'sensorNoiseScale',o.sensorNoiseScale));
assert(isequal(normal.time,reference.time) && isequal(normal.truth(1,:),reference.xDrone) ...
    && isequal(normal.truth(2,:),reference.zDrone) && strcmp(normal.terminalReason,reference.terminalReason));
assert(isequal(normal.decision.request,traj.requestedAcceleration));
limits=landing2d.environment.actionLimits(c); G=landing2d.observation.staticContext(c);
for edge=1:nEdges
    r=s.cases{edge}; d=r.decision; active=find(d.active);
    assert(strcmp(r.manifest.hash,normal.manifest.hash) && r.edgeId==edge);
    prefix=find(r.time<=o.cutStart+1e-9 & r.time<=normal.time(end)+1e-9);
    assert(isequal(r.time(prefix),normal.time(prefix)) && isequal(r.truth(:,prefix),normal.truth(:,prefix)));
    assert(~any(d.supervisorIntervened) && max(abs(d.request-d.appliedAccelerationIntervalMean),[],'all')<1e-12);
    assert(all(d.actorAlpha(edge,active)==0));
    assert(isequal(d.request(:,~d.active),d.nominalAtCurrentObservation(:,~d.active)));
    if isempty(active), continue; end
    assert(all(d.time(active)>=o.cutStart-1e-9 & d.time(active)<o.cutStart+o.cutDuration-1e-9));
    k=active(1); state=landing2d.graphstate.observationVectorGraph(d.observation(:,k),G,c);
    keep=true(nEdges,1); keep(edge)=false;
    [~,~,mu]=landing2d.rl.policyAction(agent,state,[],true,keep);
    assert(isequal(d.request(:,k),limits.*tanh(mu)));
    [~,cache]=landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,state,'policy');
    assert(isequal(d.actorAlpha(keep,k),cache.cache1.alpha(keep)));
    if r.cut.restoredInFlight
        assert(d.time(active(end)+1)>=o.cutStart+o.cutDuration-1e-9);
        assert(r.cut.actualEnd-(o.cutStart+o.cutDuration)<c.experiment.policyDt+1e-8);
    end
end
% Explicitly verify no-intervention and sub-step durations without selecting
% a more favorable scenario if any of the sixteen intervention cases fails.
late=o; late.cutStart=s.scenario.scenario.deadline+1;
noCut=landing2d.unlink.rollout(agent,c,s.scenario,late,1);
assert(isequal(noCut.truth,normal.truth) && noCut.cut.decisionCount==0);
tiny=o; tiny.cutStart=0; tiny.cutDuration=.01;
oneStep=landing2d.unlink.rollout(agent,c,s.scenario,tiny,1);
assert(oneStep.cut.decisionCount==1 && oneStep.cut.restoredInFlight);
assert(abs(oneStep.cut.appliedDuration-c.experiment.policyDt)<1e-9);
pageCount=ceil(nEdges/8); assert(numel(output.figures)==pageCount);
for page=1:pageCount
    layout=findall(output.figures(page),'Type','tiledlayout');
    assert(isscalar(layout) && isequal(layout.GridSize,[4,2]));
    ax=findall(output.figures(page),'Type','axes');
    assert(numel(ax)==8);
    for edge=8*page-7:min(8*page,nEdges)
        assert(isscalar(findobj(ax,'Tag',sprintf('unlink_edge_%02d',edge))));
    end
end
report=struct('allEdges',nEdges,'selfEdges',nNodes,'pairedManifest',true,'unchangedCheckpoint',true, ...
    'intactEqualsExistingRollout',true,'appliedCases',sum(s.summary.CutDecisions>0), ...
    'restoredCases',sum(s.summary.RestoredInFlight),'normalResult',normal.terminalReason, ...
    'cutSuccesses',sum(s.summary.CutResult=="SUCCESS"));
fprintf('UNLINK_SELF_TEST_PASS | %d/%d applied, %d restored, intact %s, cut SUCCESS %d/%d\n', ...
    report.appliedCases,nEdges,report.restoredCases,report.normalResult,report.cutSuccesses,nEdges);
end
