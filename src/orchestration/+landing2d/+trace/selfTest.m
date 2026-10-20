function report = selfTest(options)
% SELFTEST  Acceptance tests A01-A13 of the decision trace and dashboard (headless).
%   report = landing2d.trace.selfTest()                       % run_check('trace')
%   report = landing2d.trace.selfTest(struct('glossary',file)) % also check the
%            labels against INCSL glossary.tsv (canonical_ko of the cited ids)
% Uses the trained onto_rgat_ppo checkpoint of options.trainSeed (default 11)
% on S1 and S4 (replicate 1) and an invisible dashboard. A mock (untrained)
% agent appears only in A10 and is labeled TEST ONLY. Every comparison is
% exact unless a tolerance is stated.
if nargin < 1, options = struct(); end
registry = landing2d.config.methodRegistry();
if ~isfield(options,'trainSeed'), options.trainSeed = registry.trainSeeds.v23(1); end
if ~isfield(options,'glossary'), options.glossary = ''; end
root = landing2d.orchestration.projectRoot();
cfg = landing2d.config.primaryConfig(root);
if isfield(options,'outputDir') && ~isempty(options.outputDir), cfg.outputDir = options.outputDir; end
arm = landing2d.config.applyMethod(cfg,'onto_rgat_ppo',options.trainSeed);
[agent,~,file] = landing2d.rl.loadCheckpoint(arm);
agentBefore = agent;
specs = landing2d.evaluation.factorialCases(cfg);
fixture = struct();
fixture.cfg = cfg; fixture.arm = arm; fixture.agent = agent; fixture.file = file;
fixture.specs = specs; fixture.options = options;
fixture.S1 = recordCase(agent,arm,specs(1),'S1');
fixture.S4 = recordCase(agent,arm,specs(4),'S4');
checks = {@checkCadence,@checkDropout,@checkProvenance,@checkSchema,@checkOperators, ...
    @checkHonestAnimation,@checkFullChain,@checkNoSafetyClaim,@checkNonInterference, ...
    @checkCheckpoint,@checkPerformance,@checkReplay,@checkTerminology};
names = ["A01 source cadence","A02 signal-specific dropout","A03 source-to-node provenance", ...
    "A04 exact ontology schema","A05 two R-GAT operators","A06 single-layer honest animation", ...
    "A07 full-chain explanation","A08 no false safety claims","A09 policy non-interference", ...
    "A10 checkpoint reality","A11 performance","A12 replay and exports","A13 terminology"];
passed = false(numel(checks),1); messages = strings(numel(checks),1); details = strings(numel(checks),1);
for i = 1:numel(checks)
    try
        details(i) = string(checks{i}(fixture)); passed(i) = true; messages(i) = "PASS";
    catch err
        messages(i) = string(getReport(err,'basic','hyperlinks','off'));
    end
    fprintf('  trace-test [%2d/%d] %-34s %s %s\n',i,numel(checks),names(i),messages(i),details(i));
end
assert(isequaln(agent,agentBefore),'landing2d:TraceSelfTest','The trained agent changed during the tests.');
report = table(names',passed,messages,details,'VariableNames',{'Check','Passed','Message','Detail'});
assert(all(passed),'landing2d:TraceSelfTest','%d decision-trace test(s) failed.',sum(~passed));
end

% ------------------------------------------------------------------ checks
function detail = checkCadence(F)
% Camera and navigation events come from the distinct decision-time stamps;
% no event is created at a 0.01-s physics substep; accepted marker / PnP / KF
% measurement-update events exist exactly when the KF really updated.
for tr = {F.S1,F.S4}
    T = tr{1}; E = T.events; R = T.records; dt = T.context.policyDt;
    decisionTimes = [R.time];
    allowed = [decisionTimes,T.terminal.time];
    assert(all(ismember(E.Time_s,allowed)),'An event is stamped outside the decision times.');
    frames = E.Time_s(E.Type=="camera_frame");
    assert(numel(frames)==numel(unique(frames)) && isequal(frames(:),decisionTimes(:)), ...
        'Camera frames are not one per decision.');
    assert(all(abs(diff(frames)-dt) < 1e-9),'Camera inter-arrival differs from policyDt.');
    nav = E.Time_s(E.Type=="own_navigation_update");
    assert(numel(nav)==numel(unique(nav)) && all(ismember(decisionTimes,nav)));
    sensing = [R.sensing]; kf = [sensing.kf]; pnp = [sensing.pnp];
    updated = ismember({kf.update},{'measurement_update','initialization'});
    measured = E.Time_s(E.Type=="kf_measurement_update" & E.DecisionIndex<=numel(R));
    assert(isequal(measured(:),decisionTimes(updated)'),'KF measurement-update events differ from filter.updated.');
    assert(isequal(sort(E.Time_s(E.Type=="pnp_valid"))',decisionTimes([pnp.valid])), ...
        'pnp_valid events differ from accepted PnP poses.');
    assert(isequal(updated,[pnp.valid]),'A KF measurement update without an accepted PnP pose.');
    C = landing2d.trace.cadenceSummary(T);
    rate = C.ObservedRate_Hz(C.Type=="camera_frame");
    assert(abs(rate-1/dt) < 1e-6,'Observed camera rate %.3f Hz.',rate);
end
C = landing2d.trace.cadenceSummary(F.S4);
detail = sprintf('S4 camera %.2f Hz, navigation %.2f Hz (incl. terminal fix), %d frames, %d accepted', ...
    C.ObservedRate_Hz(C.Type=="camera_frame"),C.ObservedRate_Hz(C.Type=="own_navigation_update"), ...
    C.Count(C.Type=="camera_frame"),C.Count(C.Type=="kf_measurement_update"));
end

function detail = checkDropout(F)
% During the injected S4 dropout: frames exist, no marker / PnP / measurement
% update, KF time updates, visionAge grows, decisions continue.
T = F.S4; R = T.records; E = T.events;
ev = [R.evaluation]; inDropout = find([ev.injectedDropout]);
assert(numel(inDropout) >= 5,'Too few S4 decisions inside the dropout window.');
times = [R(inDropout).time];
for t = times
    rows = E(E.Time_s==t,:);
    assert(any(rows.Type=="camera_frame") && any(rows.Type=="marker_missing") ...
        && ~any(ismember(rows.Type,["marker_valid","pnp_valid","kf_measurement_update"])) ...
        && any(rows.Type=="kf_time_update") && any(rows.Type=="actor_action_decided"), ...
        'Dropout decision at %.2f s has wrong events.',t);
end
age = arrayfun(@(r)r.graph.estimate.visionAge,R(inDropout));
assert(all(diff(age) > 0),'visionAge does not grow during the dropout.');
dash = landing2d.viz.TosmTraceDashboard(T,struct('visible',false));
cleanup = onCleanup(@()delete(dash));
dash.seek(times(2));
active = string(dash.snapshot().activeSegments);
assert(~any(startsWith(active,["marker-pnp","pnp-kf"])) && any(startsWith(active,"kf-time:predicted")) ...
    && any(startsWith(active,"cam-marker:camera")),'Dashboard pulses a measurement path in the dropout.');
detail = sprintf('%d dropout decisions %.1f-%.1f s, visionAge %.2f -> %.2f s',numel(inDropout), ...
    times(1),times(end),age(1),age(end));
end

function detail = checkProvenance(F)
% Perturbation-derived o_t -> node map equals the documented TOSM table and
% every recorded X is observationVectorGraph of the recorded o_t.
T = F.S4; P = T.provenance; names = P.channelNames;
expected = { ...
    {'ugv_visionUpdated','ugv_visionAge'},{'ugv_vx'},{'relative_x','relative_height'}, ...
    {'relative_vx'},{'drone_vz','drone_sinTheta','drone_pitchRate'}, ...
    {'relative_x','relative_height','drone_sinTheta','drone_cosTheta'}, ...
    {'relative_x','relative_vx','drone_vz','drone_sinTheta','drone_cosTheta','drone_pitchRate'}};
for n = 1:7
    assert(isempty(setxor(names(P.channelToNode(:,n)),expected{n})), ...
        'Provenance of node %d: %s.',n,strjoin(names(P.channelToNode(:,n)),', '));
end
staticExpected = {{},{},{},{},{}, ...
    {'sensor.cameraPitchOffset','sensor.fov','normalization.relativePosition','normalization.height'}, ...
    {'safety.touchdownPositionTolerance','safety.touchdownSpeedX','safety.touchdownSpeedZ', ...
     'safety.touchdownPitchTolerance','safety.touchdownPitchRateTolerance', ...
     'normalization.relativePosition','normalization.vx','normalization.vz','normalization.pitchRate'}};
for n = 1:7
    assert(isempty(setxor(P.staticNames(P.staticToNode(:,n)),staticExpected{n})), ...
        'Static constants of node %d differ.',n);
end
G = F.arm; context = landing2d.observation.staticContext(F.arm);
for r = T.records
    [~,d] = landing2d.graphstate.observationVectorGraph(r.observation,context,G);
    assert(isequal(d.X,r.graph.X),'X at %.2f s is not observationVectorGraph(o_t).',r.time);
end
D = landing2d.trace.dependencyGraph(T);
for e = find(D.kind=="ch")
    for target = find(D.A(e,:))
        n = sscanf(char(D.ids(target)),'x:%d'); k = sscanf(char(D.ids(e)),'ch:%d');
        assert(P.channelToNode(k,n),'Connector %s -> %s has no provenance record.',D.ids(e),D.ids(target));
    end
end
detail = sprintf('%d derivation connectors, %d static constants, X verified at %d decisions', ...
    nnz(P.channelToNode),nnz(P.staticToNode),numel(T.records));
end

function detail = checkSchema(F)
% 7 nodes, 13 semantic + 7 self edges, 5 relation types, endpoints and types
% of the active checkpoint; any change fails loudly.
S = landing2d.trace.graphSchema(F.agent);
assert(S.nNodes==7 && numel(S.semanticEdges)==13 && numel(S.selfEdges)==7 ...
    && numel(S.relationNames)==5 && S.nEdges==20);
assert(strcmp(S.graphHash,F.agent.encoderSpec.graph.hash));
tampered = F.agent;
tampered.encoderSpec.T.rel([1 4]) = tampered.encoderSpec.T.rel([4 1]);
tampered.encoderSpec.schema.rel = tampered.encoderSpec.T.rel;
assertThrows(@()landing2d.trace.graphSchema(tampered),'landing2d:TraceSchema');
dropped = F.agent; dropped.encoderSpec.schema.nodeNames{6} = 'FieldOfView';
assertThrows(@()landing2d.trace.graphSchema(dropped),'landing2d:TraceSchema');
shuffledArm = landing2d.config.applyMethod(F.cfg,'shuffled_rgat_ppo',F.options.trainSeed);
shuffled = landing2d.rl.agentInit(shuffledArm.rl,RandStream('threefry','Seed',1),shuffledArm.graphState);
assertThrows(@()landing2d.trace.graphSchema(shuffled),'landing2d:TraceSchema');
detail = sprintf('graph %s…; swapped relation, renamed node and shuffled graph rejected',S.graphHash(1:12));
end

function detail = checkOperators(F)
% Displayed alpha / message / gate values are the encoder caches; alpha sums
% to one per destination inside each operator pool (up to the 1e-9 softmax
% denominator floor of landing2d.rgat.relationForward); softmax(score) = alpha.
S = F.S4.schema; worst = 0;
for r = [F.S1.records,F.S4.records]
    A = r.actor;
    for l = 1:size(A.alphaLayers,2)
        for pool = unique(S.edgePool)
            edges = find(S.edgePool==pool);
            alpha = A.alphaLayers(edges,l);
            sums = accumarray(S.dst(edges)',alpha,[7,1]);
            has = accumarray(S.dst(edges)',1,[7,1]) > 0;
            worst = max(worst,max(abs(sums(has)-1)));
            e = exp(A.attentionScoreLayers(edges,l));
            den = accumarray(S.dst(edges)',e,[7,1])+1e-9;
            assert(max(abs(e./den(S.dst(edges))-alpha)) < 1e-12,'softmax(score) differs from alpha.');
        end
        assert(max(abs(A.weightedMessageNormLayers(:,l)-A.alphaLayers(:,l).*A.projectedMessageNormLayers(:,l))) < 1e-12);
    end
    c = A.consistency;
    assert(c.propagateTanh < 1e-12 && c.modulateTanh < 1e-12 && c.embedding < 1e-12, ...
        'Recomputed Z_prop/Z_mod do not reproduce the encoder cache.');
    noMod = ~ismember(1:7,S.dst(S.edgePool==2));
    assert(all(A.gate(:,noMod)==1,'all'),'Gate differs from 1 at a node without modulating edges.');
end
assert(worst < 1e-8,'Pool alpha sums deviate by %.3g.',worst);
dash = landing2d.viz.TosmTraceDashboard(F.S4,struct('visible',false));
cleanup = onCleanup(@()delete(dash));
for k = [1,32,numel(F.S4.records)]
    dash.seek(F.S4.records(k).time);
    s = dash.snapshot(); r = F.S4.records(k);
    thirdPanel = r.actor.gate;
    if strcmp(S.encoderVersion,'rgat_v2'), thirdPanel = r.actor.layerH{1}; end
    assert(s.decision==k && isequal(s.alphaBars,r.actor.alphaLayers(:)) && isequal(s.X,r.graph.X) ...
        && isequal(s.H,r.actor.H) && isequal(s.gate,thirdPanel) && isequal(s.g,r.actor.g) ...
        && isequal(s.action,r.command.requestedAcceleration),'Dashboard numbers differ at decision %d.',k);
end
r = F.S4.records(32);
detail = sprintf(['pool sums |err| <= %.1e; t=%.2f s: alpha(DM->LC)=%.3f, alpha(VQ->LC)=%.3f, ' ...
    'gate(LC) mean %.3f'],worst,r.time,r.actor.alpha(11),r.actor.alpha(13),mean(r.actor.gate(:,7)));
end

function detail = checkHonestAnimation(F)
% Legend separates physical sensing, deterministic derivation, single-layer
% graph computation and explanatory highlighting; staged playback is labeled
% as a display order at one decision time; the DAG has no multi-hop path.
dash = landing2d.viz.TosmTraceDashboard(F.S4,struct('visible',false));
cleanup = onCleanup(@()delete(dash));
legendText = strjoin(dash.snapshot().legend,' ');
D = landing2d.trace.dependencyGraph(F.S4); L = D.layers;
keys = ["실제 센서 사건","결정론적 파생","메시지 전달 간선 아님","단일 R-GAT 층","동시 계산", ...
        "설명용 순서","물리적 지연","다중 홉 추론이 아님"];
if strcmp(F.S4.schema.encoderVersion,'rgat_v2')
    keys = ["실제 센서 사건","결정론적 파생","메시지 전달 간선 아님",sprintf("%d층 R-GAT",L),"동시 계산", ...
        "설명용 순서","물리적 지연",sprintf("최대 %d홉",L),"게이트 없음"];
end
for key = keys
    assert(contains(legendText,key),'Legend lacks "%s".',key);
end
dash.setStaged(true); dash.step(1);
assert(contains(dash.snapshot().phaseLabel,'물리 지연 아님'),'Staged playback is not labeled.');
% Layer l embeddings feed only layer l+1 edges; the last layer feeds none.
for l = 1:L
    for m = 1:L
        feeds = any(D.A(D.kind=="h" & D.layer==l,D.kind=="e" & D.layer==m),'all');
        assert(feeds == (m==l+1),'Layer-%d embeddings feed layer-%d edges.',l,m);
    end
end
chain = landing2d.trace.selectionChain(F.S4,10,"node:7",D);
if L == 1
    assert(any(contains(chain.lines,'다중 홉 추론 아님')));
else
    assert(any(contains(chain.lines,sprintf('최대 %d홉',L))));
end
detail = sprintf('legend layers, staged label and a %d-layer DAG (at most %d relations per path)',L,L);
end

function detail = checkFullChain(F)
% Camera, VisionQuality, an edge, LandingCondition and the Actor output give
% a source -> edge -> readout chain with stamps, values, relations and action.
T = F.S4; k = find(arrayfun(@(r)r.evaluation.injectedDropout,T.records),1);
D = landing2d.trace.dependencyGraph(T);
stamp = sprintf('t = %.2f s',T.records(k).time);
for focus = ["source:camera","node:1","edge:13","node:7","action"]
    C = landing2d.trace.selectionChain(T,k,focus,D);
    assert(any(contains(C.lines,stamp)) && any(contains(C.lines,'[가속도 명령]')) ...
        && any(contains(C.lines,'[그래프 리드아웃]')),'Chain of %s is incomplete.',focus);
    assert(~any(contains(C.lines,'NaN')),'Chain of %s prints NaN.',focus);
end
C = landing2d.trace.selectionChain(T,k,"node:7",D);
inChain = @(id)any(C.vertices==id); L = D.layers;
assert(all(arrayfun(inChain,compose("e%d:%02d",L,[9:13,20]))) ...
    && ~any(arrayfun(inChain,compose("e%d:%02d",L,1:8))), ...
    'LandingCondition chain: last-layer edges must be exactly its incoming edges.');
assert(any(contains(C.lines,'conditionsLanding')) && any(contains(C.lines,'시간 갱신')));
A = landing2d.trace.selectionChain(T,k,"action",D);
assert(sum(D.kind(A.mask)=="e")==20*D.layers && sum(D.kind(A.mask)=="src")==5);
X = landing2d.trace.explainDecision(T,k);
assert(size(X.sections,1)==8 && contains(X.banner,'[관측]') && contains(X.banner,'[추정]') ...
    && contains(X.banner,'[예측]') && contains(X.banner,'[행동]'));
broken = T; broken.records(k).graph.estimate.ugvVx = NaN; broken.records(k).graph.estimate.visionAge = Inf;
Y = landing2d.trace.explainDecision(broken,k);
assert(contains(Y.banner,'알 수 없음') && ~contains(Y.banner,'NaN') && ~contains(Y.banner,'Inf'), ...
    'Unknown values are not printed as UNKNOWN.');
detail = sprintf(['5 selections at %s, LandingCondition chain: last-layer edges = 5 ' ...
    'conditionsLanding + self'],stamp);
end

function detail = checkNoSafetyClaim(F)
% LandingCondition is only current-state ratios r/(1+r) (0.5 at the limit),
% never a landing grant, safety guarantee, contact prediction or action.
forbidden = ["착륙 승인됨","착륙을 승인함","착륙 허가","안전 보장됨","안전합니다","충돌 없음","접촉 예측됨"];
T = F.S4;
for k = 1:numel(T.records)
    X = landing2d.trace.explainDecision(T,k);
    content = [X.banner,X.sections{:,2}];
    assert(~any(contains(content,forbidden)),'Affirmative safety wording at decision %d.',k);
    r = T.records(k); ratio = r.graph.semanticEvidence.touchdownLimitRatio;
    assert(max(abs(r.graph.X(1:5,7)'-ratio./(1+ratio))) < 1e-12);
end
X = landing2d.trace.explainDecision(T,1);
assert(any(contains(X.sections{4,2},'착륙 승인·안전 보장·미래 접촉 예측·PPO 행동이 아님')));
vs = T.context.observationNames; v = zeros(numel(vs),1); G = landing2d.observation.staticContext(F.arm);
tolerance = F.arm.experiment.safety.touchdownPositionTolerance; s = G.normalization.relativePosition;
v(strcmp(vs,'relative_x')) = tolerance/(tolerance+s); v(strcmp(vs,'drone_cosTheta')) = 1;
[~,d] = landing2d.graphstate.observationVectorGraph(v,G,F.arm);
assert(abs(d.X(1,7)-0.5) < 1e-6,'Position ratio at the tolerance is %.6f, not 0.5.',d.X(1,7));
detail = sprintf('%d decisions without affirmative safety wording; feature = 0.5 at the limit',numel(T.records));
end

function detail = checkNonInterference(F)
% Same checkpoint, seed and event schedule: traced (with and without a live
% dashboard feed) and evaluation rollouts give identical actions,
% observations, rewards, contacts and outcome; the agent is unchanged.
for spec = F.specs([1 4])
    for deterministic = [true,false]
        options = struct('deterministic',deterministic,'scenario',spec.scenario, ...
            'sensorEvents',spec.sensorEvents);
        [result,traj] = landing2d.rl.rolloutEpisodeV2(F.agent,F.arm,spec.seed,options);
        T = landing2d.trace.recordEpisode(F.agent,F.arm,spec.seed,options);
        compareRollout(T,result,traj,sprintf('%s deterministic=%d',spec.id,deterministic));
    end
end
spec = F.specs(4);
dash = [];
fed = struct('deterministic',true,'scenario',spec.scenario,'sensorEvents',spec.sensorEvents, ...
    'onStart',@start,'onRecord',@feed);
T = landing2d.trace.recordEpisode(F.agent,F.arm,spec.seed,fed);
cleanup = onCleanup(@()delete(dash));
[result,traj] = landing2d.rl.rolloutEpisodeV2(F.agent,F.arm,spec.seed,struct('deterministic',true, ...
    'scenario',spec.scenario,'sensorEvents',spec.sensorEvents));
compareRollout(T,result,traj,'S4 with dashboard feed');
assert(isempty(T.callbackError),'Dashboard callback failed: %s',T.callbackError);
detail = 'S1/S4 x deterministic/stochastic and S4 with live feed: bit-identical';
    function start(skeleton)
        dash = landing2d.viz.TosmTraceDashboard(skeleton,struct('mode','live','visible',false));
    end
    function feed(record)
        dash.appendRecord(record); dash.render();
    end
end

function detail = checkCheckpoint(F)
% The trained checkpoint passes signature and graph verification; an
% incompatible configuration is refused; a mock run is labeled TEST ONLY.
info = dir(F.file);
assert(~isempty(info),'Checkpoint file missing.');
stale = landing2d.config.applyMethod(F.cfg,'onto_rgat_ppo',F.options.trainSeed);
stale.rl.ppoIterations = stale.rl.ppoIterations+1;
assertThrows(@()landing2d.rl.loadCheckpoint(stale),'landing2d:CheckpointMismatch');
missing = stale; missing.rl.policyFile = 'checkpoints/does_not_exist.mat';
assertThrows(@()landing2d.rl.loadCheckpoint(missing),'landing2d:CheckpointNotFound');
landing2d.rl.verifyCheckpointGraph(F.agent,F.arm);
mockAgent = landing2d.rl.agentInit(F.arm.rl,RandStream('threefry','Seed',3),F.arm.graphState);
spec = F.specs(1);
T = landing2d.trace.recordEpisode(mockAgent,F.arm,spec.seed,struct('scenario',spec.scenario, ...
    'sensorEvents',spec.sensorEvents,'maxDecisions',5,'identity', ...
    struct('modelStatus','TEST ONLY: untrained agentInit weights (not a trained policy)')));
dash = landing2d.viz.TosmTraceDashboard(T,struct('mode','test','visible',false));
cleanup = onCleanup(@()delete(dash));
assert(contains(dash.snapshot().mode,'TEST ONLY') && contains(T.identity.modelStatus,'TEST ONLY'));
detail = sprintf('%s (%s), stale signature and missing file refused, mock labeled TEST ONLY', ...
    info.name,F.agent.encoderSpec.graph.hash(1:12));
end

function detail = checkPerformance(F)
% Bounded work per decision; the event log of a live feed equals the trace
% (lossless) although graphics are throttled; only decision records arrive.
T = F.S4;
skeleton = T; skeleton.records = []; skeleton.terminal.terminated = false;
skeleton.events = landing2d.trace.buildEvents(skeleton);
dash = landing2d.viz.TosmTraceDashboard(skeleton,struct('mode','live','visible',false));
cleanup = onCleanup(@()delete(dash));
started = tic;
for r = T.records, dash.appendRecord(r); end
perRecord = toc(started)/numel(T.records);
liveEvents = dash.Trace.events;
decided = sum(T.events.DecisionIndex <= numel(T.records));
assert(height(liveEvents)==decided && isequaln(liveEvents,T.events(1:decided,:)), ...
    'Live event log differs from the recorded log.');
dash.finalize(T);
started = tic;
for k = 1:numel(T.records), dash.seek(T.records(k).time); end
perFrame = toc(started)/numel(T.records);
assert(perRecord < 0.5 && perFrame < 0.5,'Too slow: %.3f s per record, %.3f s per frame.',perRecord,perFrame);
detail = sprintf('%d records, %d events lossless; %.1f ms per append, %.1f ms per decision render', ...
    numel(T.records),height(T.events),1e3*perRecord,1e3*perFrame);
end

function detail = checkReplay(F)
% Saved S1 / S4 traces reload identically, explanations are reproduced from
% the stored numbers without simulation, and the replayed dashboard shows the
% same panels as the live-fed one. PNG / CSV / JSON exports exist.
folder = fullfile(tempdir,'landing2d_trace_selftest');
if isfolder(folder), rmdir(folder,'s'); end
for tr = {F.S1,F.S4}
    T = tr{1};
    files = landing2d.trace.exportTrace(T,folder,T.identity.scenarioId);
    [loaded,annotations] = landing2d.trace.loadTrace(files.mat);
    assert(isequaln(loaded,T),'Reloaded trace differs.');
    for k = 1:numel(T.records)
        X = landing2d.trace.explainDecision(loaded,k);
        assert(isequal(X.banner,annotations(k).banner) && isequal(X.sections,annotations(k).sections));
    end
    events = readtable(files.events,'TextType','string');
    assert(height(events)==height(T.events));
    decisions = readtable(files.decisions);
    assert(height(decisions)==numel(T.records));
    session = jsondecode(fileread(files.session,'Encoding','UTF-8'));
    assert(session.decisions==numel(T.records) && strcmp(session.schema.graphHash,T.schema.graphHash));
    assert(isfile(files.provenance));
end
live = landing2d.viz.TosmTraceDashboard(F.S4,struct('mode','live','visible',false));
replayed = landing2d.viz.TosmTraceDashboard(loaded,struct('mode','replay','visible',false));
cleanup = onCleanup(@()cellfun(@delete,{live,replayed}));
for k = [1,32,numel(F.S4.records)]
    live.seek(F.S4.records(k).time); replayed.seek(F.S4.records(k).time);
    a = live.snapshot(); b = replayed.snapshot();
    a = rmfield(a,{'mode','renderCount'}); b = rmfield(b,{'mode','renderCount'});
    assert(isequaln(a,b),'Replay differs from live at decision %d.',k);
end
png = fullfile(folder,'S4_replay.png');
replayed.select("node:7"); replayed.exportPng(png);
assert(isfile(png),'PNG export failed.');
detail = sprintf('S1 (%d) and S4 (%d decisions) reloaded; exports in %s',numel(F.S1.records), ...
    numel(F.S4.records),folder);
end

function detail = checkTerminology(F)
% Preferred Korean / English terms; KF time vs measurement update used only
% for the matching event; node feature (X) vs node embedding (H); score vs
% coefficient; pose vs attitude.
L = landing2d.trace.labels(); t = L.terms;
pairs = {t.nodeFeature,'노드 특징','node feature'; t.nodeEmbedding,'노드 임베딩','node embedding'; ...
    t.attentionScore,'어텐션 점수','attention score'; t.attentionCoefficient,'어텐션 계수','attention coefficient'; ...
    t.timeUpdate,'시간 갱신','time update'; t.measurementUpdate,'측정 갱신','measurement update'; ...
    t.pose,'포즈','pose'; t.attitude,'자세','attitude'; t.kalmanFilter,'칼만 필터','KF'; ...
    t.markerDetection,'마커 검출','marker detection'; t.fov,'시야각','FOV'; ...
    t.messagePassing,'메시지 전달','message passing'; t.rgat,'관계형 그래프 어텐션 네트워크','R-GAT'; ...
    t.stateEstimation,'상태 추정','state estimation'; t.relationType,'관계 유형','relation type'; ...
    t.edge,'간선','edge'; t.navigationEstimate,'자체 항법 추정','navigation estimate'};
for i = 1:size(pairs,1)
    assert(contains(pairs{i,1},pairs{i,2}) && contains(pairs{i,1},pairs{i,3}),'Label %s.',pairs{i,1});
end
T = F.S4;
for k = 1:numel(T.records)
    X = landing2d.trace.explainDecision(T,k); kfLines = strjoin(X.sections{2,2},' ');
    switch T.records(k).sensing.kf.update
        case 'time_update', assert(contains(kfLines,'시간 갱신') && ~contains(kfLines,'측정 갱신 ('));
        case 'measurement_update', assert(contains(kfLines,'측정 갱신') && ~contains(kfLines,'시간 갱신'));
    end
end
C = landing2d.trace.selectionChain(T,1,"action");
assert(any(contains(C.lines,'노드 특징 X_')) && any(contains(C.lines,'노드 임베딩 H')) ...
    && any(contains(C.lines,'어텐션 점수 e')) && any(contains(C.lines,'어텐션 계수 α')));
detail = sprintf('%d label pairs, KF wording per decision',size(pairs,1));
if ~isempty(F.options.glossary) && isfile(F.options.glossary)
    G = readtable(F.options.glossary,'FileType','text','Delimiter','\t','TextType','string', ...
        'VariableNamingRule','preserve');
    ids = ["T16-0022","T15-0113","T15-0119","T18-0054","T16-0021","T15-0326","T03-0001", ...
        "T03-0004","T03-0005","T03-0028","T12-0098","T04-0031","T01-0058","T12-0001","T15-0108"];
    want = ["노드 특징","노드 임베딩","메시지 전달","간선","관계 유형","어텐션 계수","측정 갱신", ...
        "시간 갱신","칼만 필터","상태 추정","마커 검출","포즈","자세","시야각","관계형 그래프 어텐션 네트워크"];
    for i = 1:numel(ids)
        row = G(G.id==ids(i),:);
        assert(height(row)==1 && row.canonical_ko==want(i),'Glossary %s is %s.',ids(i),strjoin(row.canonical_ko));
    end
    detail = [detail,sprintf('; %d canonical_ko matched in glossary.tsv',numel(ids))];
end
end

% ----------------------------------------------------------------- helpers
function T = recordCase(agent,arm,spec,id)
T = landing2d.trace.recordEpisode(agent,arm,spec.seed,struct('scenario',spec.scenario, ...
    'sensorEvents',spec.sensorEvents,'identity',struct('scenarioId',id, ...
    'modelStatus','trained checkpoint (training signature + graph hash verified)')));
end

function compareRollout(T,result,traj,label)
R = T.records;
cat2 = @(f)cell2mat(arrayfun(f,R,'UniformOutput',false));
same = isequal([R.observation],traj.observation) && isequal([R.policyInput],traj.state) ...
    && isequal(cat2(@(r)r.actor.preTanhAction),traj.command) ...
    && isequal(cat2(@(r)r.actor.mu),traj.actorMean) ...
    && isequal(cat2(@(r)r.actor.normalizedAction),traj.normalizedAction) ...
    && isequal(cat2(@(r)r.command.requestedAcceleration),traj.requestedAcceleration) ...
    && isequal(cat2(@(r)r.command.appliedAccelerationIntervalMean),traj.appliedAccelerationIntervalMean) ...
    && isequal(arrayfun(@(r)r.step.reward,R),traj.reward) ...
    && isequal(arrayfun(@(r)r.critic.value,R),traj.value) ...
    && isequal(arrayfun(@(r)r.actor.logProbability,R),traj.logProbability) ...
    && isequal([R.time],traj.time) && strcmp(T.terminal.reason,result.terminalReason) ...
    && isequal(arrayfun(@(r)r.evaluation.truth.droneX,R),result.xDrone(1:numel(R))) ...
    && isequal(arrayfun(@(r)r.evaluation.truth.padX,R),result.xPad(1:numel(R))) ...
    && isequaln(T.terminal.time,result.time(end));
assert(same,'landing2d:TraceInterference','Traced rollout differs from rolloutEpisodeV2 (%s).',label);
end

function assertThrows(fun,id)
threw = false;
try, fun(); catch err, threw = strcmp(err.identifier,id); end
assert(threw,'Expected error %s.',id);
end
