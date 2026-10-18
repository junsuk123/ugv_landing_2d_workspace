function r=rollout(agent,c,spec,o,edgeId,progress)
% ROLLOUT Direct frozen-policy flight through existing reset/step functions.
% edgeId=0 is the intact control. This does not duplicate dynamics, rewards,
% sensors, or termination. Evaluation truth/manifest never enter inference.
t=agent.encoderSpec.T;
if nargin<6, progress=[]; end
if isstruct(edgeId)
    selected=landing2d.unlink.selection(t,edgeId.nodeIds,edgeId.edgeIds);
    edgeId=NaN; % interactive combination, not an individual numbered case
else
    validateattributes(edgeId,{'numeric'},{'scalar','integer','>=',0,'<=',t.nEdges});
    ids=edgeId; if edgeId==0, ids=[]; end
    selected=landing2d.unlink.selection(t,[],ids);
end
[env,observation]=landing2d.environment.reset(c,spec.seed, ...
    struct('scenario',spec.scenario,'sensorEvents',spec.sensorEvents, ...
    'sensorNoiseScale',o.sensorNoiseScale));
manifest=landing2d.environment.exogenousManifest(env);
capacity=ceil(env.scenario.deadline/c.experiment.policyDt)+2;
states=nan(8,capacity+1); times=nan(1,capacity+1);
states(:,1)=truth(env); times(1)=env.time;
decision=struct('time',nan(1,capacity),'dt',nan(1,capacity), ...
    'observation',nan(numel(observation),capacity),'active',false(1,capacity), ...
    'request',nan(2,capacity),'nominalAtCurrentObservation',nan(2,capacity), ...
    'appliedAccelerationIntervalMean',nan(2,capacity),'actorAlpha',nan(t.nEdges,capacity), ...
    'actorCut',false(t.nEdges,capacity),'actorDisabledNodes',false(t.nNodes,capacity), ...
    'reward',nan(1,capacity),'supervisorIntervened',false(1,capacity));
limits=landing2d.environment.actionLimits(c); k=0;
while ~env.episodeStatus.terminated && ~env.episodeStatus.truncated
    assert(k<capacity,'landing2d:UnlinkTimeout','Environment exceeded its declared decision budget.');
    k=k+1; active=selected.hasCuts && env.time>=o.cutStart-1e-9 ...
        && env.time<o.cutStart+o.cutDuration-1e-9;
    intervention=[];
    if active
        intervention=struct('actorKeep',selected.edgeKeep,'criticKeep',[],'actorNodeKeep',[]);
        if ~isempty(selected.nodeIds), intervention.actorNodeKeep=selected.nodeKeep; end
    end
    d=landing2d.livetest.infer(agent,c,observation,env.observationContext,intervention);
    decision.time(k)=env.time; decision.observation(:,k)=observation;
    decision.active(k)=active; decision.request(:,k)=d.request;
    decision.nominalAtCurrentObservation(:,k)=d.nominalRequest;
    decision.actorAlpha(:,k)=d.actorAlpha;
    decision.actorCut(:,k)=d.actorCut; decision.actorDisabledNodes(:,k)=d.actorDisabledNodes;
    [env,observation,reward,~,~,info]=landing2d.environment.step(env,d.request./limits);
    decision.dt(k)=info.dt; decision.reward(k)=reward;
    decision.appliedAccelerationIntervalMean(:,k)=info.appliedAccelerationIntervalMean;
    decision.supervisorIntervened(k)=info.supervisorIntervened;
    states(:,k+1)=truth(env); times(k+1)=env.time;
    if ~isempty(progress) && mod(k,20)==0, progress(env.time,env.scenario.deadline); end
end
for name=string(fieldnames(decision))', decision.(name)=decision.(name)(:,1:k); end
active=find(decision.active);
cut=struct('edgeId',edgeId,'head','actor','plannedStart',o.cutStart, ...
    'plannedEnd',o.cutStart+o.cutDuration,'actualStart',NaN,'actualEnd',NaN, ...
    'appliedDuration',0,'decisionCount',numel(active),'restoredInFlight',false, ...
    'reason','intact');
if selected.hasCuts
    cut.reason='episode_ended_before_cut';
    if ~isempty(active)
        cut.actualStart=decision.time(active(1)); cut.actualEnd=times(active(end)+1);
        cut.appliedDuration=sum(decision.dt(active));
        cut.restoredInFlight=active(end)<k;
        if cut.restoredInFlight, cut.reason='restored'; else, cut.reason='terminal_during_cut'; end
    end
end
r=struct('edgeId',edgeId,'selection',selected,'time',times(1:k+1),'truth',states(:,1:k+1), ...
    'decision',decision,'cut',cut,'manifest',manifest,'status',env.episodeStatus, ...
    'terminalReason',env.episodeStatus.terminalReason,'return',sum(decision.reward));
end

function v=truth(env)
s=env.physicalState; p=env.pad;
v=[s.x;s.z;s.vx;s.vz;s.theta;p.x;p.z;p.vx];
end
