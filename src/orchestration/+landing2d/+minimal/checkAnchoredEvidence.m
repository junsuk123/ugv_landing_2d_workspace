function checkAnchoredEvidence()
% CHECKANCHOREDEVIDENCE TEST ONLY: anchored source, refined query, exact gradient.
root = landing2d.orchestration.projectRoot();
c = landing2d.minimal.config(root,'v32');
old = landing2d.minimal.config(root,'v31');
assert(isequaln(c.rl,old.rl) && isequaln(c.experiment,old.experiment) ...
    && isequaln(c.evaluation,old.evaluation),'Common study contract changed.');
for method = {'ppo','onto_rgat_ppo','shuffled_rgat_ppo'}
    cfg = landing2d.config.applyMethod(c,method{1},271);
    prior = landing2d.config.applyMethod(old,method{1},271);
    agent = landing2d.rl.initialAgent(cfg); previous = landing2d.rl.initialAgent(prior);
    assert(isequaln(agent.policy,previous.policy) && isequaln(agent.value,previous.value));
    profile = landing2d.rl.profileAgent(agent,cfg,2001,1);
    assert(profile.parameterCount==1419);
    signature = landing2d.rl.trainingSignature(cfg);
    assert(strcmp(signature.algorithmVersion,'minimal-relational-v3.2'));
    assert(landing2d.rl.signatureMatches(signature,cfg));
    assert(~landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(prior),cfg));
end
cfg = landing2d.config.applyMethod(c,'onto_rgat_ppo',271);
agent = landing2d.rl.initialAgent(cfg); p = agent.policy.encoder; spec = agent.encoderSpec;
rs = RandStream('threefry','Seed',73);
x = .2*randn(rs,40,3); dG = randn(rs,8,3);
[g,cache] = landing2d.minimal.encoderForward(p,spec,x);
[grad,dx] = landing2d.minimal.encoderBackward(p,spec,cache,dG);
assert(isequal(cache.layers{1}.relation.source,cache.layers{2}.relation.source));
assert(isequal(cache.layers{1}.relation.Xf,cache.H0) ...
    && isequal(cache.layers{2}.relation.Xf,cache.H0));
assert(isequal(cache.layers{2}.relation.queryFlat,reshape(cache.layers{1}.H,8,[])));
prior = spec; prior.encoderVersion = 'rgat_minimal_v2';
[~,priorCache] = landing2d.minimal.encoderForward(p,prior,x);
assert(isequal(cache.layers{1}.H,priorCache.layers{1}.H),'First hop must stay identical.');
assert(~isequal(g,priorCache.g),'Anchoring did not affect the second hop.');
for k = 1:3
    one = landing2d.minimal.encoderForward(p,spec,x(:,k));
    assert(max(abs(g(:,k)-one))<1e-12);
end
for k = 1:2
    totals = spec.T.Msel*cache.layers{k}.relation.alpha;
    assert(max(abs(totals-1),[],'all')<1e-12);
end
step = 1e-6; maximumError = 0;
for name = fieldnames(p)'
    key = name{1};
    for k = 1:numel(p.(key))
        plus = p; minus = p;
        plus.(key)(k) = plus.(key)(k)+step; minus.(key)(k) = minus.(key)(k)-step;
        numerical = (objective(plus,spec,x,dG)-objective(minus,spec,x,dG))/(2*step);
        maximumError = max(maximumError,abs(numerical-grad.(key)(k)));
    end
end
for k = 1:numel(x)
    plus = x; minus = x; plus(k) = plus(k)+step; minus(k) = minus(k)-step;
    numerical = (objective(p,spec,plus,dG)-objective(p,spec,minus,dG))/(2*step);
    maximumError = max(maximumError,abs(numerical-dx(k)));
end
assert(maximumError<2e-7,'Anchored encoder derivative error %.3g.',maximumError);
% Quality affects hop-two motion weights through the destination context.
fresh = zeros(40,4); stale = fresh;
for k = 1:4
    [~,o] = landing2d.environment.reset(cfg,2000+k);
    o(9:10) = [1;0]; fresh(:,k) = landing2d.minimal.features(o);
    o(9:10) = [0;.6]; stale(:,k) = landing2d.minimal.features(o);
end
[~,f] = landing2d.minimal.encoderForward(p,spec,fresh);
[~,s] = landing2d.minimal.encoderForward(p,spec,stale);
change = zeros(1,2);
for k = 1:2
    fs = f.layers{k}.relation.score; ss = s.layers{k}.relation.score;
    change(k) = max(abs((fs(2,:)-fs(3,:))-(ss(2,:)-ss(3,:))));
end
assert(change(1)<1e-12 && change(2)>1e-7,'Quality context path is inactive.');
landing2d.minimal.checkLearningPath(c);
fprintf('    TEST ONLY anchored evidence: all 371 parameters + 120 inputs, max error %.3g\n',maximumError);
end

function value = objective(p,spec,x,dG)
g = landing2d.minimal.encoderForward(p,spec,x);
value = sum(g.*dG,'all');
end
