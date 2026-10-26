function T = branchRollouts(runs,d,seeds)
% BRANCHROLLOUTS Paired continuations from exact environment snapshots (Q2).
% The planar environment draws all sensor noise from its time-indexed tables,
% so a copy of the env struct is an exact snapshot (checked in selfTest).
% For each frozen policy and development seed (v2 motion OOD) the policy flies
% the episode; at the decisions nearest to T1 (acceleration start), T1+T2/2
% and T1+T2+1 s the snapshot is continued three times: the policy's own action
% (Delta = 0) and a_x + Delta (normalized, clipped to [-1,1]) for
% holdDecisions decisions, then the same frozen policy until termination.
% The Delta = 0 branch must reproduce the original rollout exactly. Outcomes
% are the frozen policy's return-to-go, success, unsafe contact and the aim
% error RMS over the next aimHorizon seconds. This is a local test of the
% chosen action under the policy's own continuation, not an optimal policy.
if nargin<3, seeds = d.branch.seeds; end
q = d.branch; deltas = [0,q.deltaAx];
rows = cell(1,numel(runs));
for r = 1:numel(runs)
    run = runs(r);
    [envConfig,scale] = landing2d.bias_diagnostics.condition(d,run.config,q.factor,q.shift);
    agent = run.agent; parts = cell(1,numel(seeds));
    parfor i = 1:numel(seeds)
        parts{i} = oneSeed(agent,envConfig,seeds(i),scale,q,deltas);
    end
    P = vertcat(parts{:}); m = height(P);
    rows{r} = [table(repmat(string(run.id),m,1),repmat(run.trainSeed,m,1), ...
        'VariableNames',{'MethodId','TrainSeed'}),P];
end
T = vertcat(rows{:});
end

function P = oneSeed(agent,c,seed,scale,q,deltas)
[env,observation] = landing2d.environment.reset(c,seed,struct('sensorNoiseScale',scale));
s = env.scenario;
targets = [s.T1,s.T1+s.T2/2,s.T1+s.T2+1];
capacity = ceil(s.deadline/c.experiment.policyDt)+1;
snapshots = cell(1,3); snapObs = cell(1,3); snapIndex = zeros(1,3); snapTime = NaN(1,3);
rewards = zeros(1,capacity); k = 0;
while ~env.episodeStatus.terminated && k<capacity
    for b = 1:3
        if isempty(snapshots{b}) && env.time>=targets(b)-1e-9
            snapshots{b} = env; snapObs{b} = observation; snapIndex(b) = k; snapTime(b) = env.time;
        end
    end
    a = tanh(policyMean(agent,c,env,observation));
    [env,observation,reward] = landing2d.environment.step(env,a);
    k = k+1; rewards(k) = reward;
end
originalReason = string(env.episodeStatus.terminalReason); total = k;
rows = {};
for b = 1:3
    if isempty(snapshots{b}), continue; end
    originalReturn = sum(rewards(snapIndex(b)+1:total));
    for delta = deltas
        out = continueFrom(agent,c,snapshots{b},snapObs{b},delta,q,capacity-snapIndex(b));
        if delta==0
            assert(out.returnToGo==originalReturn && out.reason==originalReason, ...
                'landing2d:BiasDiagnosticsSnapshot','The Delta = 0 branch must reproduce the rollout.');
        end
        rows{end+1} = struct('EnvironmentSeed',seed,'Point',string(q.points{b}), ...
            'BranchTime',snapTime(b),'Delta',delta,'ReturnToGo',out.returnToGo, ...
            'Success',double(out.reason=="SUCCESS"),'Unsafe',double(ismember(out.reason, ...
            ["UNSAFE_CONTACT","UNAUTHORIZED_CONTACT","MISSED_PAD_CONTACT","SAFETY_ENVELOPE_VIOLATION"])), ...
            'TerminalReason',out.reason,'AimRmsHorizon',out.aimRms); %#ok<AGROW>
    end
end
if isempty(rows)
    P = table();
else
    P = struct2table([rows{:}]);
end
end

function out = continueFrom(agent,c,env,observation,delta,q,capacity)
rewards = zeros(1,capacity); k = 0; start = env.time; aim = []; dts = [];
while ~env.episodeStatus.terminated && k<capacity
    a = tanh(policyMean(agent,c,env,observation));
    if k<q.holdDecisions && delta~=0
        a(1) = min(max(a(1)+delta,-1),1);
    end
    if env.time-start<q.aimHorizon
        state = env.physicalState; pad = landing2d.scenario.padState(env.scenario,env.time);
        aim(end+1) = landing2d.evaluation.aimError(pad.x,state.x,state.z-env.scenario.padHeight,c); %#ok<AGROW>
    end
    [env,observation,reward,~,~,info] = landing2d.environment.step(env,a);
    if numel(aim)>numel(dts), dts(end+1) = info.dt; end %#ok<AGROW>
    k = k+1; rewards(k) = reward;
end
aimRms = NaN;
if ~isempty(aim), aimRms = sqrt(sum(aim.^2.*dts)/sum(dts)); end
% Same summation as the original rollout's suffix, so Delta = 0 is bit-comparable.
out = struct('returnToGo',sum(rewards(1:k)),'reason',string(env.episodeStatus.terminalReason),'aimRms',aimRms);
end

function mu = policyMean(agent,c,env,observation)
if strcmp(agent.encoderSpec.mode,'baseline')
    policyInput = observation;
else
    policyInput = landing2d.graphstate.environmentGraph(env,c,observation);
end
[~,~,mu] = landing2d.rl.policyAction(agent,policyInput,[],true);
end
