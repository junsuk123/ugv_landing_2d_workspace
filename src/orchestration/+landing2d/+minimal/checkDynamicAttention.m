function checkDynamicAttention()
% CHECKDYNAMICATTENTION Expressivity/causal-path tests, not performance data.
[~,T] = landing2d.minimal.schema(); d = 8;
W = repmat(eye(d),1,1,3); a = zeros(1,19); a(1:2) = 1;
X = zeros(d,4,2);
X(1,2,:) = 1; X(2,3,:) = 1;
X(1:2,4,1) = [1;-2]; X(1:2,4,2) = [-2;1];
[~,cache] = landing2d.minimal.dynamicForward(X,W,a,T);
logOdds = log(cache.alpha(2,:)./cache.alpha(3,:));
assert(logOdds(1)>0 && logOdds(2)<0, ...
    'A destination query must be able to reverse motion-neighbor ranking.');
% Stable normalization must also handle large finite scores.
[Z,large] = landing2d.minimal.dynamicForward(1000*X,W,1000*a,T);
assert(all(isfinite(Z),'all') && all(isfinite(large.alpha),'all'));
c = landing2d.config.applyMethod(landing2d.minimal.config(),'onto_rgat_ppo',271);
agent = landing2d.rl.initialAgent(c);
assert(agent.encoderSpec.layers==2 && strcmp(agent.encoderSpec.weightSharing,'across_hops'));
observations = zeros(10,4);
for j = 1:4, [~,observations(:,j)] = landing2d.environment.reset(c,2000+j); end
fresh = observations; stale = observations;
fresh(9:10,:) = repmat([1;0],1,4); stale(9:10,:) = repmat([0;.6],1,4);
xf = zeros(40,4); xs = xf;
for j = 1:4
    xf(:,j) = landing2d.minimal.features(fresh(:,j));
    xs(:,j) = landing2d.minimal.features(stale(:,j));
end
[~,f] = landing2d.minimal.encoderForward(agent.policy.encoder,agent.encoderSpec,xf);
[~,s] = landing2d.minimal.encoderForward(agent.policy.encoder,agent.encoderSpec,xs);
change = zeros(1,2);
for j = 1:2
    af = f.layers{j}.relation.alpha; as = s.layers{j}.relation.alpha;
    change(j) = max(abs(log(af(2,:)./af(3,:))-log(as(2,:)./as(3,:))));
end
assert(change(1)<1e-12 && change(2)>1e-7, ...
    'Quality must reach the second-hop motion weights through the graph.');
% Model parameters, observations and PPO losses of the MLP baseline stay exact.
root = landing2d.orchestration.projectRoot();
v3 = landing2d.config.applyMethod(landing2d.minimal.config(root,'v3'),'ppo',271);
v31 = landing2d.config.applyMethod(landing2d.minimal.config(root,'v31'),'ppo',271);
old = landing2d.rl.initialAgent(v3); current = landing2d.rl.initialAgent(v31);
assert(isequaln(old.policy,current.policy) && isequaln(old.value,current.value));
assert(isequaln(v3.experiment,v31.experiment) && isequaln(v3.rl,v31.rl));
[~,~,oldMu] = landing2d.rl.policyAction(old,observations,[],true);
[~,~,newMu] = landing2d.rl.policyAction(current,observations,[],true);
assert(isequal(oldMu,newMu),'The PPO baseline path changed.');
fprintf('    TEST ONLY: query ranking reverses; quality reaches hop 2; PPO path unchanged\n');
end
