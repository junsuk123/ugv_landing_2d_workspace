function test_ppo_smoke_v2()
% One bounded PPO iteration: integration evidence, not performance evidence.
c = landing2d.config.primaryConfig(fileparts(fileparts(mfilename('fullpath'))));
c=landing2d.graphstate.applyStateRepresentation(c,'context_rgat');
c.rl.ppoIterations=1; c.rl.episodesPerIteration=2; c.rl.ppoEpochs=1;
c.rl.miniBatch=64; c.rl.evaluateEvery=1; c.rl.valueWarmup=0;
c.rl.parallelEpisodes=false; c.rl.verbose=false;
rs=RandStream('threefry','Seed',1234);
a=landing2d.rl.agentInit(c.rl,rs,c.graphState);
[env,obs]=landing2d.environment.reset(c,12); %#ok<ASGLU>
S=landing2d.graphstate.contextGraph(env.packet,c);
[u,lp,mu]=landing2d.rl.policyAction(a,S,rs,false);
sigma=exp(a.policy.logStd);
expected=sum(-0.5*((u-mu)./sigma).^2-a.policy.logStd-0.5*log(2*pi));
assert(abs(lp-expected)<1e-12);
[a,h]=landing2d.rl.ppoTrain(a,c,rs); %#ok<ASGLU>
assert(numel(h)>=2 && all(isfinite([h.score])));
assert(all(~[h.graphAdaptation]));
end
