function profile = profileAgent(agent,c,seed,repetitions)
% PROFILEAGENT  Small deterministic inference profile (not a hard realtime proof).
% Observation time: vectorizing the policy observation (planar: the 12-D common
% observation vector, 3D: the causal packet). Graph time: building the context
% graph from the same causal observation.
if nargin<3, seed=1; end
if nargin<4, repetitions=50; end
[env,observation]=landing2d.environment.reset(c,seed);
mode=agent.encoderSpec.mode;
if strcmp(mode,'baseline')
    state=observation;
else
    state=landing2d.graphstate.environmentGraph(env,c,observation);
end
% Exclude one-time MATLAB dispatch/JIT setup from the steady-state profile.
warmRs=RandStream('threefry','Seed',1);
for i=1:min(20,repetitions)
    policyObservation(env,c);
    if ~strcmp(mode,'baseline')
        landing2d.graphstate.environmentGraph(env,c,observation);
    end
    landing2d.rl.policyAction(agent,state,warmRs,true);
    landing2d.rl.valueForward(agent,state);
end
tic;
for i=1:repetitions
    policyObservation(env,c);
end
observationMs=1000*toc/repetitions;
graphMs=0;
if ~strcmp(mode,'baseline')
    tic;
    for i=1:repetitions
        state=landing2d.graphstate.environmentGraph(env,c,observation);
    end
    graphMs=1000*toc/repetitions;
end
rs=RandStream('threefry','Seed',1);
tic;
for i=1:repetitions
    landing2d.rl.policyAction(agent,state,rs,true);
end
actorMs=1000*toc/repetitions;
tic;
for i=1:repetitions
    landing2d.rl.valueForward(agent,state);
end
criticMs=1000*toc/repetitions;
deployedMs=observationMs+graphMs+actorMs;
profile=struct('observationMs',observationMs,'graphMs',graphMs, ...
    'actorMs',actorMs,'criticMs',criticMs, ...
    'deployedInferenceMs',deployedMs,'policyInferenceMs',deployedMs, ...
    'totalInferenceMs',observationMs+graphMs+actorMs+criticMs, ...
    'parameterCount',countNumeric(agent.policy)+countNumeric(agent.value));
end

function x=policyObservation(env,c)
if isfield(env,'commonObservation') && ~isempty(env.commonObservation)
    x=landing2d.observation.toVector(env.commonObservation,env.observationContext);
else
    x=landing2d.sensing.normalizePacket(env.packet,c);
end
end

function n=countNumeric(x)
n=0;
if isnumeric(x)
    n=numel(x);
elseif isstruct(x)
    names=fieldnames(x);
    for i=1:numel(names), n=n+countNumeric(x.(names{i})); end
elseif iscell(x)
    for i=1:numel(x), n=n+countNumeric(x{i}); end
end
end
