function report = selfTest()
% SELFTEST Invariants of the active design, including its analytic derivatives.
checks = {@contract,@features,@shuffle,@gradient,@batch,@cases,@signatures,@causalInput, ...
    @landing2d.minimal.checkLearningPath,@landing2d.minimal.checkGeneralization, ...
    @landing2d.minimal.checkDynamicAttention,@landing2d.minimal.checkAnchoredEvidence};
names = ["shared-contract","lossless-features","relation-shuffle", ...
    "encoder-gradient","batch-attention","three-cases","checkpoint-isolation","causal-input", ...
    "ppo-shared-update","generalization-protocol","dynamic-quality-path","anchored-evidence"];
passed = false(numel(checks),1); messages = strings(numel(checks),1);
for k = 1:numel(checks)
    try
        checks{k}(); passed(k) = true; messages(k) = "PASS";
    catch err
        messages(k) = string(getReport(err,'basic','hyperlinks','off'));
    end
    fprintf('  minimal [%d/%d] %-22s %s\n',k,numel(checks),names(k),messages(k));
end
report = table(names',passed,messages,'VariableNames',{'Check','Passed','Message'});
assert(all(passed),'landing2d:MinimalSelfTest','%d minimal checks failed.',sum(~passed));
end

function contract()
c = landing2d.minimal.config(); old = landing2d.config.primaryConfig();
old.experiment.designVersion = c.experiment.designVersion;
assert(isequaln(c.experiment,old.experiment),'The physical/sensor/reward contract changed.');
old.rl.baselinePolicyHiddenSizes = c.rl.baselinePolicyHiddenSizes;
old.rl.baselineValueHiddenSizes = c.rl.baselineValueHiddenSizes;
assert(isequaln(c.rl,old.rl),'PPO settings changed beyond the registered head sizes.');
assert(c.graphState.encoderLearnRate==old.graphState.encoderLearnRate);
arms = landing2d.config.comparisonArms(c,struct('trainSeed',251));
for j = 1:numel(arms)
    agent = landing2d.rl.initialAgent(arms(j).config);
    profile = landing2d.rl.profileAgent(agent,arms(j).config,2001,1);
    assert(profile.parameterCount==1419,'Parameter counts must match exactly.');
    assert(isequaln(arms(j).config.experiment,c.experiment));
    landing2d.rl.runIdentity(agent,arms(j).config);
end
end

function features()
[schema,T] = landing2d.minimal.schema();
assert(isequal(sort([schema.observationIndices{:}]),1:10));
assert(T.nNodes==4 && T.nEdges==7 && T.nRelations==3);
for k = 1:10
    v = zeros(10,1); v(k) = (-1)^k*k/10;
    [x,detail] = landing2d.minimal.features(v);
    assert(isequal(sum(detail.X,2),v) && nnz(x)==1,'Observation duplicated or lost.');
end
end

function shuffle()
c = landing2d.minimal.config(); seen = [];
for seed = 251:270
    canonical = landing2d.config.applyMethod(c,'onto_rgat_ppo',seed);
    shuffled = landing2d.config.applyMethod(c,'shuffled_rgat_ppo',seed);
    a = landing2d.rl.initialAgent(canonical); b = landing2d.rl.initialAgent(shuffled);
    assert(isequal(a.policy,b.policy) && isequal(a.value,b.value),'Initial weights differ.');
    A = a.encoderSpec.T; B = b.encoderSpec.T;
    assert(isequal(A.src,B.src) && isequal(A.dst,B.dst) && isequal(sort(A.rel),sort(B.rel)));
    assert(sum(A.rel(1:3)~=B.rel(1:3))==2 && isequal(A.rel(4:7),B.rel(4:7)));
    b2 = landing2d.rl.initialAgent(shuffled);
    assert(isequal(b.encoderSpec.T,b2.encoderSpec.T),'Shuffle is not deterministic.');
    seen(end+1,:) = B.rel(1:3); %#ok<AGROW>
end
assert(size(unique(seen,'rows'),1)==2,'Expected two possible noncanonical partitions.');
end

function gradient()
c = landing2d.config.applyMethod(landing2d.minimal.config(),'onto_rgat_ppo',251);
a = landing2d.rl.initialAgent(c); p = a.policy.encoder; spec = a.encoderSpec;
rs = RandStream('threefry','Seed',73);
x = 0.2*randn(rs,40,3); dG = randn(rs,8,3);
[~,cache] = landing2d.graphstate.encoderForward(p,spec,x);
[g,dx] = landing2d.graphstate.encoderBackward(p,spec,cache,dG);
step = 1e-6; maximumError = 0;
for name = fieldnames(p)'
    key = name{1};
    for k = 1:numel(p.(key))
        plus = p; minus = p;
        plus.(key)(k) = plus.(key)(k)+step; minus.(key)(k) = minus.(key)(k)-step;
        numerical = (objective(plus,spec,x,dG)-objective(minus,spec,x,dG))/(2*step);
        maximumError = max(maximumError,abs(numerical-g.(key)(k)));
    end
end
for k = 1:numel(x)
    plus = x; minus = x; plus(k) = plus(k)+step; minus(k) = minus(k)-step;
    numerical = (objective(p,spec,plus,dG)-objective(p,spec,minus,dG))/(2*step);
    maximumError = max(maximumError,abs(numerical-dx(k)));
end
assert(maximumError<2e-7,'Encoder finite-difference error %.3g',maximumError);
fprintf('    all 371 parameters + 120 inputs: max derivative error %.3g\n',maximumError);
end

function value = objective(p,spec,x,dG)
g = landing2d.graphstate.encoderForward(p,spec,x);
value = sum(g.*dG,'all');
end

function batch()
c = landing2d.config.applyMethod(landing2d.minimal.config(),'onto_rgat_ppo',252);
a = landing2d.rl.initialAgent(c); rs = RandStream('threefry','Seed',35);
x = randn(rs,40,4);
[g,cache] = landing2d.graphstate.encoderForward(a.policy.encoder,a.encoderSpec,x);
for k = 1:4
    one = landing2d.graphstate.encoderForward(a.policy.encoder,a.encoderSpec,x(:,k));
    assert(max(abs(g(:,k)-one))<1e-12,'Batch mixes observations.');
end
for layer = 1:a.encoderSpec.layers
    totals = a.encoderSpec.T.Msel*cache.layers{layer}.relation.alpha;
    assert(max(abs(totals-1),[],'all')<1e-12,'Attention is not normalized per destination.');
end
end

function cases()
c = landing2d.minimal.config(); s = landing2d.minimal.cases(c);
assert(isequal({s.id},{'S1','S2','S3'}) && isequaln(s(1).scenario,s(2).scenario));
assert(isequal(s(1).sensorEvents,s(3).sensorEvents));
assert(isequal(s(1).eventWindow,s(2).eventWindow,s(3).eventWindow));
for k = 1:3
    assert(s(k).seed==s(1).seed && s(k).scenario.deadline==s(1).scenario.deadline ...
        && s(k).scenario.height==s(1).scenario.height);
end
assert(s(1).scenario.a2==0 && s(3).scenario.a2>0 && isfinite(s(2).sensorEvents.dropoutStart));
end

function signatures()
c = landing2d.minimal.config(); old = landing2d.config.primaryConfig();
registry = landing2d.config.methodRegistry();
for method = registry.methods
    current = landing2d.config.applyMethod(c,method.id,251);
    archived = landing2d.config.applyMethod(old,method.id,251);
    sig = landing2d.rl.trainingSignature(current);
    assert(strcmp(sig.algorithmVersion,'minimal-relational-v3.1'));
    assert(landing2d.rl.signatureMatches(sig,current));
    assert(~landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(archived),current));
    previous = landing2d.config.applyMethod(landing2d.minimal.config( ...
        landing2d.orchestration.projectRoot(),'v3'),method.id,251);
    assert(~landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(previous),current));
end
% A legacy version tag with otherwise identical settings must not use the
% old cross-feature fallback in the new profile.
current = landing2d.config.applyMethod(c,'onto_rgat_ppo',251);
current.outputDir = tempname; mkdir(fullfile(current.outputDir,'checkpoints'));
signature = landing2d.rl.trainingSignature(current);
signature.algorithmVersion = 'relational-policy-v2.15'; %#ok<NASGU>
save(fullfile(current.outputDir,current.rl.policyFile),'signature');
rejected = false;
try
    landing2d.rl.loadLatestCheckpoint(current);
catch err
    rejected = strcmp(err.identifier,'landing2d:NoValidatedCheckpoint');
end
assert(rejected,'Minimal runs must not use legacy cross-feature fallback.');
end

function causalInput()
c = landing2d.config.applyMethod(landing2d.minimal.config(),'onto_rgat_ppo',251);
[env,o] = landing2d.environment.reset(c,2001);
x = landing2d.graphstate.environmentGraph(env,c,o);
assert(isequal(x,landing2d.minimal.features(o)));
% Runtime graph construction needs only o_t; even an absent context changes nothing.
y = landing2d.graphstate.observationVectorGraph(o,struct(),c);
assert(isequal(x,y));
assert(isequal(x,landing2d.graphstate.environmentGraph(env,c)));
end
