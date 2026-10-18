function report=cutSelfTest(includeUI)
% CUTSELFTEST Actual forward/action intervention, expiry, UI, and immutability.
if nargin<1, includeUI=true; end
s=landing2d.livetest.Session(); originalAgents=s.Agents;
m=find(strcmp(s.MethodIds,'onto_rgat_ppo')); method=s.MethodIds{m};
for k=1:50, s.step(); end
before=s.Current{m}; obs=s.Observation; env=s.Env;
t=before.graph; edges=landing2d.livetest.cutEdges(t,'outgoing',3);
assert(isequal(edges,find(t.src==3 & t.dst~=3)));
for scope={'incoming','incident','relation','edge'}
    assert(~isempty(landing2d.livetest.cutEdges(t,scope{1},1)));
end
assertThrows(@()landing2d.livetest.cutEdges(t,'edge',t.nEdges+1),'landing2d:LiveTestCutTarget');
assertThrows(@()s.cut('ppo','actor','edge',1,1),'landing2d:LiveTestCutTarget');
assert(s.cut(method,'actor','outgoing',3,.25));
q=s.Current{m}; keep=~q.actorCut;
assert(all(q.actorAlpha(edges)==0) && isequal(q.actorAlpha(keep),before.actorAlpha(keep)));
assert(isequal(q.criticAlpha,before.criticAlpha) && isequal(q.value,before.value));
assert(isequal(q.nominalRequest,before.request) && isequal(s.Observation,obs));
assert(isequaln(s.Env,env) && norm(q.request-before.request)>1e-10);
actorDelta=q.request-before.request;
assert(~s.cut(method,'actor','edge',1,1)); % no accidental overlapping replacement
assert(s.Log.intervention(s.Log.count)==1 && all(s.Log.actorCut{m}(edges,s.Log.count)));
% The mask removes messages from the real aggregation, not merely the graph.
agent=s.Agents{m}; S=landing2d.graphstate.observationVectorGraph(obs,s.Env.observationContext,s.Arms{m});
[~,normalCache]=landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,S,'policy');
[~,maskedCache]=landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,S,'policy',keep);
c=normalCache.cache1;
X=reshape(S,agent.encoderSpec.inDim,agent.encoderSpec.nNodes);
[normalZ,~]=landing2d.rgat.relationForward(X,c.W,c.a,c.E,c.T,[],c.attentionMode);
[maskedZ,~]=landing2d.rgat.relationForward(X,c.W,c.a,c.E,c.T,keep,c.attentionMode);
expected=normalZ;
for edge=edges
    expected(:,t.dst(edge))=expected(:,t.dst(edge))-c.msgs(:,edge)*c.alpha(edge);
end
assert(norm(maskedZ-expected,'fro')<1e-12);
assertThrows(@()landing2d.rgat.relationBackward(zeros(size(maskedZ)),maskedCache.cache1), ...
    'landing2d:DiagnosticInferenceOnly');
assertThrows(@()landing2d.rl.policyAction(agent,S,[],false,keep),'landing2d:DiagnosticInferenceOnly');
assertThrows(@()landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,S,'policy',ones(2,1)), ...
    'MATLAB:incorrectNumel');
s.restoreCut(); assert(isequaln(s.Current{m},before) && s.ActiveCut==0);
assert(strcmp(s.CutEvents(1).endReason,'manual'));
assert(s.cut(method,'critic','relation',3,.25)); q=s.Current{m};
assert(isequal(q.request,before.request) && isequal(q.actorAlpha,before.actorAlpha));
assert(all(q.criticAlpha(q.criticCut)==0) && abs(q.value-before.value)>1e-10);
criticDelta=q.value-before.value;
s.restoreCut(); assert(isequaln(s.Current{m},before));
assert(s.cut(method,'both','edge',1,.25)); startTime=s.Env.time;
s.step(); s.step(); assert(s.ActiveCut>0);
s.step(); assert(s.ActiveCut==0 && ~any(s.Current{m}.actorCut) && ~any(s.Current{m}.criticCut));
assert(isequal(s.Current{m}.request,s.Current{m}.nominalRequest));
last=s.CutEvents(end);
assert(strcmp(last.endReason,'expired') && last.actualEnd>=startTime+.25-1e-9 ...
    && last.actualEnd<startTime+.25+s.Config.experiment.policyDt+1e-9);
% A pulse and a cut can coexist; neither uses hidden truth as policy input.
assert(s.pulse(1.5,1.2,3)); assert(s.cut(method,'both','incident',6,1));
for k=1:12, s.step(); end
assert(s.ActiveCut==0 && isequaln(originalAgents,s.Agents));
assert(s.cut(method,'actor','edge',1,1)); s.reset();
assert(isempty(s.CutEvents) && s.ActiveCut==0 && ~any(s.Current{m}.actorCut));
assert(strcmp(s.Completed{end}.cuts(end).endReason,'reset'));

% Direct flight applies the intervened actor request on the next interval.
s.configure('policy',method,1); twin=landing2d.livetest.Session(struct('mode','policy'));
assert(s.cut(method,'actor','outgoing',3,.25)); request=s.Current{m}.request;
s.step(); twin.step();
k=s.Log.count; assert(norm(s.Log.applied(:,k)-request)<1e-12 && s.Log.appliedIntervention(k)==1);
assert(norm(s.Log.truth(1:4,k)-twin.Log.truth(1:4,twin.Log.count))>1e-12);
while s.ActiveCut>0, s.step(); end
assert(all(s.Current{m}.request==s.Current{m}.nominalRequest));
file=s.save(); saved=load(file); r=saved.output.current;
assert(strcmp(saved.output.schemaVersion,'live_attention_v2') && r.log.count==numel(r.log.time));
assert(size(r.log.nominalRequests,3)==r.log.count && size(r.log.actorCut{m},2)==r.log.count);
assert(r.log.appliedIntervention(2)==1 && ~isempty(r.cuts));
% Critic-only interventions never change the physical command.
s.configure('policy',method,1); twin.reset();
assert(s.cut(method,'critic','relation',3,1)); request=s.Current{m}.nominalRequest;
s.step(); twin.step();
assert(norm(s.Log.applied(:,s.Log.count)-request)<1e-12 && s.Log.appliedIntervention(s.Log.count)==0);
assert(isequaln(s.Env.physicalState,twin.Env.physicalState));

% Episode end cancels an active cut. Terminal output is explicitly held at
% its prior decision time, so retain the matching input separately as well.
short=landing2d.livetest.Session(struct('duration',10));
for k=1:98, short.step(); end
assert(~short.cut(method,'actor','edge',1,1)); % would exceed the deadline
assert(short.cut(method,'actor','edge',1,.2));
while ~short.done(), short.step(); end
assert(short.ActiveCut==0 && strcmp(short.CutEvents(end).endReason,'terminal'));
k=short.Log.count;
assert(short.Log.inferenceTime(k)<short.Log.time(k) && short.Log.appliedIntervention(k)==0); % hold driver
assert(isequal(short.Log.policyObservation(:,k),short.InferenceObservation));
short.reset(); assert(~any(short.Current{m}.actorCut));

uiPassed=false;
if includeUI
    app=landing2d.livetest.App(struct('figureVisible',false)); cleanup=onCleanup(@()delete(app));
    for k=1:30, app.stepOnce(); end
    callback=app.UI.CutScope.ValueChangedFcn;
    for scope={'edge','incoming','incident','relation','outgoing'}
        app.UI.CutScope.Value=scope{1}; callback([],[]);
        assert(~isempty(app.UI.CutTarget.ItemsData));
    end
    app.UI.CutDuration.Value=.3;
    callback=app.UI.Cut.ButtonPushedFcn; callback([],[]);
    assert(app.Session.ActiveCut>0 && strcmp(app.UI.Cut.Enable,'off'));
    frozenTime=app.Session.Env.time; pause(.2); assert(app.Session.Env.time==frozenTime && app.Session.ActiveCut>0);
    for k=1:4, app.stepOnce(); end
    assert(app.Session.ActiveCut==0 && strcmp(app.UI.Restore.Enable,'off'));
    app.UI.CutDuration.Value=3; app.UI.CutHead.Value='both'; app.triggerCut();
    callback=app.UI.Restore.ButtonPushedFcn; callback([],[]); assert(app.Session.ActiveCut==0);
    app.triggerPulse(); app.triggerCut();
    for k=1:8, app.stepOnce(); end
    folder=fullfile(landing2d.orchestration.projectRoot(),'results','live_attention','validation');
    exportapp(app.Figure,fullfile(folder,'gui_edge_cut.png'));
    callback=app.UI.Graph.ValueChangedFcn; callback([],[]); % target refresh leaves active intervention intact
    assert(app.Session.ActiveCut>0);
    app.start(); pause(.6); app.pause(); assert(isempty(app.LastError));
    app.reset(); assert(app.Session.ActiveCut==0);
    delete(app); clear cleanup; uiPassed=true;
end
for k=1:numel(s.Identities)
    after=landing2d.rl.runIdentity(s.Agents{k},s.Arms{k},s.Identities{k}.CheckpointFile);
    assert(strcmp(after.CheckpointHash,s.Identities{k}.CheckpointHash));
end
assert(isequaln(s.Agents,originalAgents));
report=struct('actorDelta',actorDelta,'criticDelta',criticDelta,'uiPassed',uiPassed, ...
    'checkpointUnchanged',true,'expirySimulationSeconds',last.actualEnd-startTime);
fprintf('LIVE_EDGE_CUT_SELF_TEST_PASS | Actor delta [%+.6f %+.6f], Critic delta %+.6f\n', ...
    actorDelta(1),actorDelta(2),criticDelta);
end

function assertThrows(fun,id)
try
    fun();
catch err
    assert(strcmp(err.identifier,id),'Expected %s, got %s',id,err.identifier); return;
end
error('landing2d:ExpectedError','Expected %s.',id);
end
