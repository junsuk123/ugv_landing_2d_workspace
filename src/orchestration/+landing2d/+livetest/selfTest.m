function report=selfTest(includeUI)
% SELFTEST Live-only regression, including five-minute causal-driver flight.
if nargin<1, includeUI=true; end
folder=fullfile(landing2d.orchestration.projectRoot(),'results','live_attention','validation');
if ~isfolder(folder), mkdir(folder); end
s=landing2d.livetest.Session(); originalAgents=s.Agents; identities=s.Identities;

% Original and explicit empty-pulse paths must agree bit-for-bit.
p=rmfield(s.Env.scenario,'liveAccelerationPulses'); t=linspace(0,p.deadline,1001);
[x,v,a,phase]=landing2d.scenario.evaluateTrajectory(p,t);
[xx,vv,aa,pp]=landing2d.scenario.evaluateTrajectory(s.Env.scenario,t);
assert(isequal(x,xx)&&isequal(v,vv)&&isequal(a,aa)&&isequal(phase,pp));
for k=1:50, s.step(); end
before=s.Env.pad; alphaBefore=s.Current{2}.actorAlpha;
assert(s.pulse(1.5,1.2,3));
assert(isequal(before.x,s.Env.pad.x)&&isequal(before.vx,s.Env.pad.vx));
assert(isequal(alphaBefore,s.Current{2}.actorAlpha)); % no magical immediate inference jump
assert(~s.pulse(1.5,1.2,3)); % no overlapping pulse cycles
p=s.Env.scenario;
[~,vEnd]=landing2d.scenario.evaluateTrajectory(p,5+2*1.2+3);
assert(abs(vEnd-s.Options.initialPadSpeed)<1e-12);
for boundary=[5 6.2 9.2 10.4]
    [x1,v1]=landing2d.scenario.evaluateTrajectory(p,boundary-1e-8);
    [x2,v2]=landing2d.scenario.evaluateTrajectory(p,boundary+1e-8);
    assert(abs(x1-x2)<1e-6 && abs(v1-v2)<1e-6);
end
for k=1:30, s.step(); end
% The planar primary now uses learned relation-type weights that are fixed
% with respect to the observation. Node features and commands still change.
assert(isequal(s.Current{2}.actorAlpha,alphaBefore));
q=s.Current{2}; topology=q.graph;
for n=1:topology.nNodes
    assert(abs(sum(q.actorAlpha(topology.dst==n))-1)<1e-7);
    edges=topology.src==n & topology.dst~=n;
    assert(abs(q.actorNode(n)-mean(q.actorAlpha(edges)))<1e-12);
end
% Independent old inference route must agree exactly with inspection output.
for m=1:numel(s.Agents)
    input=s.Observation;
    if m>1, input=landing2d.graphstate.environmentGraph(s.Env,s.Arms{m},s.Observation); end
    u=landing2d.rl.policyAction(s.Agents{m},input,[],true);
    assert(max(abs(s.Current{m}.request-landing2d.environment.actionLimits(s.Config).*tanh(u)))<1e-12);
end
fprintf('Live attention: topology, pulse continuity, read-only inference PASS.\n');

% Finish a 300 s flight, with repeatable manual-like interventions.
triggerTimes=[60 120 180 240]; next=1;
while ~s.done()
    if next<=numel(triggerTimes) && s.Env.time>=triggerTimes(next)-1e-8
        assert(s.pulse(1.5,1.2,3)); next=next+1;
    end
    s.step();
end
assert(abs(s.Env.time-300)<1e-8 && strcmp(s.Env.episodeStatus.terminalReason,'TASK_TIMEOUT'));
assert(min(s.Log.truth(2,1:s.Log.count)-s.Config.padHeight)>2);
assert(isequaln(s.Agents,originalAgents));
longRecord=s.record();
fprintf('Live attention: 300 s hold flight with 5 acceleration cycles PASS.\n');
s.configure('policy','onto_rgat_ppo',1);
while ~s.done(), s.step(); end
assert(s.Env.episodeStatus.terminated);
policyOutcome=s.Env.episodeStatus.terminalReason;
s.reset(); assert(s.Env.time==0 && ~s.done() && isempty(s.Events));
assert(strcmp(s.Completed{end-1}.options.mode,'hold') && strcmp(s.Completed{end}.options.mode,'policy'));
file=s.save(); loaded=load(file); assert(strcmp(loaded.output.schemaVersion,'live_attention_v2'));
fprintf('Live attention: direct-policy termination (%s), reset, mode logs PASS.\n',policyOutcome);

uiPassed=false;
if includeUI
    app=landing2d.livetest.App(struct('figureVisible',false)); cleanup=onCleanup(@()delete(app));
    app.stepOnce(); [ok,~]=app.triggerPulse(); assert(ok);
    for k=1:25, app.stepOnce(); end
    app.UI.Mode.Value='policy'; callback=app.UI.Mode.ValueChangedFcn; callback([],[]);
    assert(strcmp(app.Session.Options.mode,'policy') && app.Session.Env.time==0);
    app.UI.Mode.Value='hold'; callback([],[]);
    app.start(); pause(.8); app.pause();
    assert(app.Session.Env.time>0 && isempty(app.LastError));
    callback=app.UI.Pulse.ButtonPushedFcn; callback([],[]);
    for k=1:20, app.stepOnce(); end
    exportapp(app.Figure,fullfile(folder,'gui_preview.png'));
    timerHandle=app.Timer; delete(app); assert(~isvalid(timerHandle));
    clear cleanup;
    uiPassed=true; fprintf('Live attention: GUI callbacks, timer, mode switch, cleanup PASS.\n');
end
for m=1:numel(identities)
    after=landing2d.rl.runIdentity(s.Agents{m},s.Arms{m},identities{m}.CheckpointFile);
    assert(strcmp(after.CheckpointHash,identities{m}.CheckpointHash));
end
report=struct('longFlightSeconds',longRecord.log.time(end),'pulseCount',numel(longRecord.events), ...
    'minimumHeight',min(longRecord.log.truth(2,:)-s.Config.padHeight),'policyOutcome',policyOutcome, ...
    'uiPassed',uiPassed,'checkpointUnchanged',true);
report.edgeCut=landing2d.livetest.cutSelfTest(includeUI);
save(fullfile(folder,'self_test.mat'),'report','longRecord','-v7.3');
fprintf('LIVE_ATTENTION_SELF_TEST_PASS\n');
end
