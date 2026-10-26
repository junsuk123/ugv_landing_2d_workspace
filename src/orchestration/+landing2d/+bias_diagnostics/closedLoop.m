function [phases,episodes] = closedLoop(runs,d,seeds)
% CLOSEDLOOP Frozen-policy rollouts for reward density (Q3) and action topology (Q4).
% Deterministic rollouts in the protocol-v2 cells (d.rollout.cells) on the
% already-opened development seeds. reward_v5 is not changed: every step's
% reward is split into its registered parts and the split must reproduce the
% environment reward (|difference| < 1e-12):
%   goal    = -(dt/T_ref) w_goal  c_goal       view = -(dt/T_ref) w_view c_view
%   control = -(dt/T_ref) w_ctrl  c_ctrl       readiness, shaping (potential), terminal
% Phase of a decision: contact (terminal contact step) > dropout (inside the
% injected dropout) > acceleration (inside the UGV CA phase) > tracking.
% Episode outcomes must equal the stored protocol-v2 development rollouts.
if nargin<3, seeds = d.rollout.seeds; end
cells = d.rollout.cells;
stored = readtable(fullfile(d.v2Evaluation,'generalizationEpisodes.csv'),'TextType','string');
phaseRows = {}; episodeRows = {};
for r = 1:numel(runs)
    run = runs(r);
    for c = 1:size(cells,1)
        [envConfig,scale] = landing2d.bias_diagnostics.condition(d,run.config,cells{c,1},cells{c,2});
        options = struct('deterministic',true,'run',run.identity,'sensorNoiseScale',scale);
        identity = struct('Factor',string(cells{c,1}),'Shift',string(cells{c,2}));
        agent = run.agent; parts = cell(1,numel(seeds)); outcomes = cell(1,numel(seeds));
        parfor i = 1:numel(seeds)
            [result,traj] = landing2d.rl.rolloutEpisodeV2(agent,envConfig,seeds(i),options);
            parts{i} = phaseTable(result,traj,envConfig,d.saturationThreshold);
            row = landing2d.evaluation.episodeMetrics(result,traj,envConfig, ...
                setfield(identity,'EpisodeSeed',seeds(i)),[]); %#ok<SFLD>
            outcomes{i} = struct('EpisodeSeed',seeds(i),'Success',row.Success, ...
                'Unsafe',row.Unsafe,'AimErrorRMS_m',row.AimErrorRMS_m, ...
                'FailureClass',string(row.FailureClass),'Steps',traj.count);
        end
        lead = table(repmat(string(run.id),numel(seeds),1),repmat(run.trainSeed,numel(seeds),1), ...
            repmat(identity.Factor,numel(seeds),1),repmat(identity.Shift,numel(seeds),1), ...
            'VariableNames',{'MethodId','TrainSeed','Factor','Shift'});
        E = [lead,struct2table([outcomes{:}])];
        for i = 1:height(E)
            s = stored(stored.MethodId==E.MethodId(i) & stored.TrainSeed==E.TrainSeed(i) ...
                & stored.Factor==E.Factor(i) & stored.Shift==E.Shift(i) ...
                & stored.EpisodeSeed==E.EpisodeSeed(i),:);
            assert(height(s)==1 && s.Success==E.Success(i) && s.Unsafe==E.Unsafe(i) ...
                && abs(s.AimErrorRMS_m-E.AimErrorRMS_m(i))<=1e-9*max(1,abs(s.AimErrorRMS_m)), ...
                'landing2d:BiasDiagnosticsReplay','Rollout differs from the stored v2 evaluation.');
        end
        episodeRows{end+1} = E; %#ok<AGROW>
        for i = 1:numel(seeds)
            P = parts{i}; m = height(P);
            phaseRows{end+1} = [table(repmat(string(run.id),m,1),repmat(run.trainSeed,m,1), ...
                repmat(identity.Factor,m,1),repmat(identity.Shift,m,1),repmat(seeds(i),m,1), ...
                'VariableNames',{'MethodId','TrainSeed','Factor','Shift','EpisodeSeed'}),P]; %#ok<AGROW>
        end
    end
end
phases = vertcat(phaseRows{:}); episodes = vertcat(episodeRows{:});
end

function P = phaseTable(result,traj,c,threshold)
n = traj.count; t = traj.time; dt = traj.dt;
w = c.experiment.reward;
scenario = result.scenario; events = result.resetInfo.evaluatorMetadata.sensorEvents;
contact = ismember(string(result.terminalReason), ...
    ["SUCCESS","UNSAFE_CONTACT","UNAUTHORIZED_CONTACT","MISSED_PAD_CONTACT"]);
phase = repmat("tracking",1,n);
phase(scenario.a2>0 & t>=scenario.T1 & t<scenario.T1+scenario.T2) = "acceleration";
phase(t>=events.dropoutStart & t<events.dropoutEnd) = "dropout";
if contact, phase(n) = "contact"; end
names = {'goal','view','control','readiness','shaping','terminal'};
values = zeros(6,n);
for k = 1:n
    q = traj.rewardComponents{k}; scale = q.dt/w.referenceTime;
    values(:,k) = [-scale*w.goalWeight*q.runningGoalCost;-scale*w.viewWeight*q.viewCost; ...
        -scale*w.controlWeight*q.controlCost;q.readinessReward;q.potentialShaping;q.terminalBonus];
    assert(abs(sum(values(1:3,k))+q.scaledRunningCost)<=1e-12 ...
        && abs(sum(values(:,k))-traj.reward(k))<=1e-12, ...
        'landing2d:BiasDiagnosticsReward','The reward split does not reproduce reward_v5.');
end
req = traj.requestedAcceleration; applied = traj.appliedAccelerationIntervalMean;
rate = [zeros(2,1),diff(req,1,2)./dt(1:n-1)]; hasRate = [false,true(1,n-1)];
labels = ["tracking","acceleration","dropout","contact"];
P = cell(1,numel(labels));
for p = 1:numel(labels)
    in = phase==labels(p);
    if ~any(in), continue; end
    row = table(labels(p),sum(in),sum(dt(in)),'VariableNames',{'Phase','Steps','Seconds'});
    for j = 1:numel(names)
        v = values(j,in);
        row.([names{j},'Sum']) = sum(v); row.([names{j},'AbsSum']) = sum(abs(v));
        row.([names{j},'Nonzero']) = sum(abs(v)>1e-12);
    end
    row.SaturatedX = sum(abs(traj.normalizedAction(1,in))>threshold);
    row.SaturatedZ = sum(abs(traj.normalizedAction(2,in))>threshold);
    row.Intervened = sum(traj.safetyIntervened(in));
    row.RequestedAppliedGapSum = sum(vecnorm(req(:,in)-applied(:,in),2,1));
    row.RateSqX = sum(rate(1,in&hasRate).^2); row.RateSqZ = sum(rate(2,in&hasRate).^2);
    row.RateCount = sum(in&hasRate);
    row.MuAbsX = sum(abs(traj.actorMean(1,in))); row.MuAbsZ = sum(abs(traj.actorMean(2,in)));
    P{p} = row;
end
P = vertcat(P{:});
end
