function E = referenceEpisode(c,seed,noiseScale)
% REFERENCEEPISODE One deterministic reference-driver flight with the H3 acceleration estimate.
% The causal reference driver (landing2d.probe.referenceDriver, no driver
% noise) flies the configuration C; per decision boundary k = 0..n:
%   time, estimate (a_hat_x of the CA KF, 0 before initialization),
%   initialized, truth (pad acceleration a_pad, evaluation only)
% plus the scenario (T1, T2, a2) and the terminal reason. The driver reads the
% common observation only; the acceleration estimate never feeds it, so the
% trajectory does not depend on the CA KF settings.
[env,~] = landing2d.environment.reset(c,seed,struct('sensorNoiseScale',noiseScale));
capacity = ceil(env.scenario.deadline/c.experiment.policyDt)+1;
time = NaN(1,capacity+1); estimate = time; truth = time; initialized = false(1,capacity+1);
k = 1; [time(k),estimate(k),initialized(k),truth(k)] = record(env);
while ~env.episodeStatus.terminated && k <= capacity
    a = landing2d.probe.referenceDriver(env.commonObservation,env.observationContext,c,[],0);
    env = landing2d.environment.step(env,a);
    k = k+1; [time(k),estimate(k),initialized(k),truth(k)] = record(env);
end
s = env.scenario;
E = struct('seed',seed,'noiseScale',noiseScale,'time',time(1:k),'estimate',estimate(1:k), ...
    'initialized',initialized(1:k),'truth',truth(1:k),'T1',s.T1,'T2',s.T2,'a2',s.a2, ...
    'endTime',env.time,'terminalReason',string(env.episodeStatus.terminalReason));
end

function [t,estimate,initialized,truth] = record(env)
ugv = env.commonObservation.ugv;
t = env.time; initialized = ugv.accelerationInitialized;
estimate = 0;
if initialized, estimate = ugv.accelerationX; end
truth = env.pad.ax;
end
