function report=interactiveSelfTest(includeUI)
% INTERACTIVESELFTEST Node removal, full-flight masks, click bindings, cache.
if nargin<1, includeUI=true; end
root=landing2d.orchestration.projectRoot(); folder=fullfile(root,'results','unlink','interactive_validation');
if ~isfolder(folder), mkdir(folder); end
c=landing2d.config.applyMethod(landing2d.config.primaryConfig(root),'onto_rgat_ppo',1,1);
[agent,~,file]=landing2d.rl.loadCheckpoint(c); originalAgent=agent;
identity=landing2d.rl.runIdentity(agent,c,file); t=agent.encoderSpec.T;
specs=landing2d.paper.representativeScenarios(c); spec=specs(1);
o=landing2d.unlink.options(struct('cutStart',0,'cutDuration',spec.scenario.deadline));
normal=landing2d.unlink.rollout(agent,c,spec,o,0);
[reference,traj]=landing2d.rl.rolloutEpisodeV2(agent,c,spec.seed, ...
    struct('deterministic',true,'scenario',spec.scenario,'sensorEvents',spec.sensorEvents));
assert(isequal(normal.truth(1,:),reference.xDrone)&&isequal(normal.truth(2,:),reference.zDrone) ...
    && isequal(normal.decision.request,traj.requestedAcceleration));
G=landing2d.observation.staticContext(c);
S=landing2d.graphstate.observationVectorGraph(normal.decision.observation(:,40),G,c);
base=landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,S,'policy');
allKept=landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,S,'policy',[],true(t.nNodes,1));
assert(isequal(base,allKept));
for node=1:t.nNodes
    selected=landing2d.unlink.selection(t,node,[]);
    [g,cache]=landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,S, ...
        'policy',selected.edgeKeep,selected.nodeKeep);
    assert(all(cache.Xf(:,node)==0) && all(cache.H(:,node)==0));
    assert(all(cache.cache1.alpha(~selected.effectiveEdgeKeep)==0));
    % Selected node's features cannot influence any output via scores,
    % messages, local W0/b0, or grouped readout once deactivated.
    changed=reshape(S,agent.encoderSpec.schema.inDim,t.nNodes);
    changed(:,node)=[.93;-.87;.71;-.65;.41;-.32];
    counter=landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,changed(:), ...
        'policy',selected.edgeKeep,selected.nodeKeep);
    assert(isequal(g,counter));
    mustThrow(@()landing2d.graphstate.encoderBackward(agent.policy.encoder,agent.encoderSpec,cache,ones(size(g))), ...
        'landing2d:DiagnosticInferenceOnly');
end
zero=landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,S,'policy',[],false(t.nNodes,1));
assert(isequal(zero,tanh(agent.policy.encoder.bg))); % only downstream bias remains
mustThrow(@()landing2d.rl.policyAction(agent,S,[],false,[],false(t.nNodes,1)),'landing2d:DiagnosticInferenceOnly');

selected=landing2d.unlink.selection(t,3,2);
r=landing2d.unlink.rollout(agent,c,spec,o,selected);
assert(strcmp(r.manifest.hash,normal.manifest.hash) && all(r.decision.active));
assert(all(r.decision.actorCut==~selected.effectiveEdgeKeep,'all'));
assert(all(r.decision.actorDisabledNodes==~selected.nodeKeep,'all'));
assert(all(r.decision.actorAlpha(~selected.effectiveEdgeKeep,:)==0,'all'));
assert(~r.cut.restoredInFlight && r.cut.actualStart==0 && r.cut.actualEnd==r.time(end));
assert(norm(r.decision.request-r.decision.appliedAccelerationIntervalMean,'fro')<1e-12);
d=landing2d.livetest.infer(agent,c,normal.decision.observation(:,40),G, ...
    struct('actorKeep',selected.edgeKeep,'criticKeep',[],'actorNodeKeep',selected.nodeKeep));
assert(isequal(d.value,d.nominalValue)); % actor-only intervention, critic intact
assert(isequaln(agent,originalAgent));
fprintf('Interactive unlink: %d-node feature/message/readout removal, entire-flight pairing PASS.\n',t.nNodes);

uiPassed=false; files=struct();
if includeUI
    app=run_unlink(struct('figureVisible',false)); cleanup=onCleanup(@()delete(app));
    assert(isequal(app.Normal.truth,app.Current.truth));
    baseline=app.Normal; agentBefore=app.Agent;
    % Invoke the callbacks actually attached to graphical objects, not just
    % an alternate public API. Edge/node indices must retain checkpoint order.
    edge=app.UI.EdgeLines(1); callback=edge.ButtonDownFcn; callback(edge,[]);
    assert(isequal(app.Selection.edgeIds,1) && all(app.Current.decision.actorCut(1,:)));
    hits=app.CacheHits; label=app.UI.EdgeLabels(1); callback=label.ButtonDownFcn; callback(label,[]);
    assert(isempty(app.Selection.edgeIds) && app.CacheHits==hits+1 && isequal(app.Current.truth,baseline.truth));
    node=app.UI.NodeHandles(3); callback=node.ButtonDownFcn; callback(node,[]);
    assert(isequal(app.Selection.nodeIds,3) && all(app.Current.decision.actorDisabledNodes(3,:)));
    nodeLabel=app.UI.NodeLabels(3); callback=nodeLabel.ButtonDownFcn; callback(nodeLabel,[]);
    assert(isempty(app.Selection.nodeIds) && isequal(app.Current.truth,baseline.truth));
    callback=app.UI.Relations.CellEditCallback; callback([],struct('Indices',[2,1],'NewData',false));
    assert(isequal(app.Selection.edgeIds,find(t.rel==2)));
    callback=app.UI.Nodes.CellEditCallback; callback([],struct('Indices',[6,1],'NewData',false));
    assert(isequal(app.Selection.nodeIds,6));
    lastEdge=t.nEdges;
    callback=app.UI.Edges.CellEditCallback; callback([],struct('Indices',[lastEdge,1],'NewData',false));
    assert(ismember(lastEdge,app.Selection.edgeIds));
    callback=app.UI.Restore.ButtonPushedFcn; callback([],[]);
    assert(~app.Selection.hasCuts && isequal(app.Current.truth,baseline.truth));
    app.recompute(); assert(isequal(app.Current.truth,baseline.truth));
    app.setSelection(3,1); assert(isempty(app.LastError)&&~app.Busy);
    assert(strcmp(app.UI.Save.Enable,'on') && isequaln(agentBefore,app.Agent));
    exportapp(app.Figure,fullfile(folder,'gui_selected.png'));
    files=app.saveResult(); saved=load(files.mat);
    assert(isequal(saved.result.selection.nodeIds,3) && isequal(saved.result.selection.edgeIds,1));
    assert(isequal(saved.result.disabled.truth,app.Current.truth));
    app.UI.Scenario.Value='S2'; callback=app.UI.Scenario.ValueChangedFcn; callback([],[]);
    assert(strcmp(app.Spec.id,'S2') && app.Spec.seed==41002 && isequal(app.Selection.nodeIds,3));
    assert(~strcmp(app.Normal.manifest.hash,baseline.manifest.hash) && isempty(app.LastError));
    app.restoreAll(); assert(isequal(app.Normal.truth,app.Current.truth));
    figureHandle=app.Figure; delete(app); assert(~isgraphics(figureHandle)); clear cleanup;
    uiPassed=true;
    fprintf('Interactive unlink: graph callbacks, checkbox groups, cache, restore, scenario reset, save PASS.\n');
end
after=landing2d.rl.runIdentity(agent,c,file);
assert(strcmp(after.CheckpointHash,identity.CheckpointHash));
report=struct('nodeMasksVerified',t.nNodes,'normalEqualsExistingRollout',true, ...
    'fullFlightMask',true,'uiPassed',uiPassed,'checkpointUnchanged',true,'savedFiles',files);
save(fullfile(folder,'verification.mat'),'report');
fprintf('INTERACTIVE_UNLINK_SELF_TEST_PASS\n');
end

function mustThrow(callback,id)
try
    callback();
catch err
    assert(strcmp(err.identifier,id),'Expected %s, got %s.',id,err.identifier); return;
end
error('landing2d:ExpectedError','Expected %s.',id);
end
