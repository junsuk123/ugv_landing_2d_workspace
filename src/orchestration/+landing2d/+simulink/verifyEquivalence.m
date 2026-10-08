function report = verifyEquivalence(options)
% VERIFYEQUIVALENCE  Simulink 환경·정책이 MATLAB 계약과 같은지 확인.
%
%   report = landing2d.simulink.verifyEquivalence()
%   report = landing2d.simulink.verifyEquivalence(struct('methods',{{'onto_rgat_ppo'}}, ...
%       'seedCount',3))
%
% 비교군과 검증 seed마다 두 가지를 봅니다.
%   replay      MATLAB rolloutEpisodeV2(결정론)의 명령 u를 Action player 모델에서
%               재생합니다. 동역학·패드·카메라 잡음·추적기·감독기·종료·보상·관측이
%               비트 단위로 같아야 합니다 (차이 0).
%   closedLoop  같은 정책을 rlPPOAgent로 바꿔 RL Agent 블록이 운전합니다.
%               RL Toolbox 망은 single로 계산하므로 종료 사유와 결정 수가 같고
%               보상 차이가 closedLoopTolerance 이하이면 통과입니다.
%   driver      비교군과 무관한 인과적 구동기(landing2d.probe.referenceDriver)의 명령을
%               u = atanh(a)로 바꿔 MATLAB 환경과 Action player 모델에서 똑같이
%               재생합니다. 미학습 정책이 닿지 않는 착륙·최종 하강·접촉 경로까지
%               비트 단위로 같아야 합니다 (차이 0).
% 비교군은 landing2d.config.comparisonArms(학습 시드 1, 그래프 시드 1)입니다. 서명이
% 맞는 체크포인트(<checkpointDir>/checkpoints/<method_id>_s1[_g1].mat)가 있으면 그
% 정책을, 없으면 같은 학습 시드의 초기 정책(교란군은 교란 그래프)을 씁니다.
if nargin < 1, options = struct(); end
projectRoot = landing2d.orchestration.projectRoot();
cfg = landing2d.config.primaryConfig(projectRoot);
registry = landing2d.config.methodRegistry();
defaults = struct('methods',{{registry.methods.id}}, ...
    'seedCount',2,'checkpointDir',cfg.outputDir, ...
    'closedLoopTolerance',1e-3,'verbose',true);
options = mergeOptions(options,defaults);
arms = landing2d.config.comparisonArms(cfg,struct('methods',{cellstr(options.methods)}));
rows = {};
for m = 1:numel(arms)
    mode = arms(m).id;
    arm = arms(m).config;
    arm.rl.verbose = false;
    [agent,source] = policyFor(arm,options.checkpointDir);
    arm.outputDir = fullfile(tempdir,'landing2d_simulink_verify');
    seeds = arm.experiment.manifest.validationSeeds(1:options.seedCount);
    player = landing2d.simulink.buildModel(arm,struct('actionSource','player', ...
        'save',false));
    toolbox = landing2d.rlsim.toolboxAgent(agent,arm,'raw');
    toolbox.UseExplorationPolicy = false;
    assignin('base','landing2dAgent',toolbox);
    closed = landing2d.simulink.buildModel(arm,struct('save',false));
    for i = 1:numel(seeds)
        [result,traj] = landing2d.rl.rolloutEpisodeV2(agent,arm,seeds(i), ...
            struct('deterministic',true));
        replay = simulate(player,landing2d.simulink.SeedListSource(arm, ...
            seeds(i),{traj.command}));
        loop = simulate(closed,landing2d.simulink.SeedListSource(arm,seeds(i)));
        n = min(numel(replay.rewards),traj.count);
        m2 = min(size(replay.observations,2),size(traj.state,2));
        rewardDiff = max(abs(replay.rewards(1:n)-traj.reward(1:n)));
        observationDiff = max(abs(replay.observations(:,1:m2)-traj.state(:,1:m2)),[],'all');
        replayPass = strcmp(replay.reason,result.terminalReason) ...
            && numel(replay.rewards) == traj.count && rewardDiff == 0 ...
            && observationDiff == 0;
        k = min(numel(loop.rewards),traj.count);
        loopDiff = max(abs(loop.rewards(1:k)-traj.reward(1:k)));
        loopPass = strcmp(loop.reason,result.terminalReason) ...
            && numel(loop.rewards) == traj.count ...
            && loopDiff <= options.closedLoopTolerance;
        driver = driverCheck(arm,seeds(i),player);
        rows(end+1,:) = {string(mode),string(source),seeds(i), ...
            string(result.terminalReason),traj.count,string(replay.reason), ...
            numel(replay.rewards),rewardDiff,observationDiff,replayPass, ...
            string(loop.reason),numel(loop.rewards),loopDiff,loopPass, ...
            string(driver.matlabReason),string(driver.simulinkReason), ...
            driver.decisions,driver.rewardDiff,driver.observationDiff,driver.pass}; %#ok<AGROW>
        if options.verbose
            fprintf(['%-13s seed %d  MATLAB %-22s %4d | replay diff %.3g/%.3g %s' ...
                ' | closed loop %-22s diff %.3g %s | driver %-12s diff %.3g/%.3g %s\n'], ...
                mode,seeds(i),result.terminalReason,traj.count,rewardDiff,observationDiff, ...
                passText(replayPass),loop.reason,loopDiff,passText(loopPass), ...
                driver.simulinkReason,driver.rewardDiff,driver.observationDiff, ...
                passText(driver.pass));
        end
    end
    close_system(player,0);
    close_system(closed,0);
end
report = cell2table(rows,'VariableNames',{'MethodId','Policy', ...
    'Seed','MatlabReason','MatlabDecisions','ReplayReason','ReplayDecisions', ...
    'ReplayMaxRewardDiff','ReplayMaxObservationDiff','ReplayPass', ...
    'ClosedLoopReason','ClosedLoopDecisions','ClosedLoopMaxRewardDiff', ...
    'ClosedLoopPass','DriverMatlabReason','DriverSimulinkReason','DriverDecisions', ...
    'DriverMaxRewardDiff','DriverMaxObservationDiff','DriverPass'});
landing2d.simulink.episodeServer('clear');
end

function out = simulate(model,source)
landing2d.simulink.episodeServer('setSource',source);
landing2d.simulink.episodeServer('advance');
sim(model);
episode = landing2d.simulink.episodeServer('current');
entries = [episode.log{:}];
rewards = [entries.reward];
out = struct('rewards',rewards(2:end),'observations',[entries.observation], ...
    'reason','');
if ~isempty(episode.outcome), out.reason = episode.outcome.terminalReason; end
end

function out = driverCheck(arm,seed,player)
% Reference-driver commands (landing, final descent, contact) replayed in both
% environments with the same u, so tanh(u) is identical on both sides.
record = landing2d.probe.recordReference(arm,seed);
u = atanh(min(max(record.driverAction,-1+1e-9),1-1e-9));
[env,observation] = landing2d.environment.reset(arm,seed);
rewards = zeros(1,size(u,2)); states = [];
for k = 1:size(u,2)
    states(:,k) = policyState(env,observation,arm); %#ok<AGROW>
    [env,observation,rewards(k),terminated] = landing2d.environment.step(env,tanh(u(:,k)));
    if terminated, break; end
end
n = k; rewards = rewards(1:n);
replay = simulate(player,landing2d.simulink.SeedListSource(arm,seed,{u(:,1:n)}));
m = min(numel(replay.rewards),n);
q = min(size(replay.observations,2),size(states,2));
out = struct('matlabReason',env.episodeStatus.terminalReason, ...
    'simulinkReason',replay.reason,'decisions',n, ...
    'rewardDiff',max(abs(replay.rewards(1:m)-rewards(1:m))), ...
    'observationDiff',max(abs(replay.observations(:,1:q)-states(:,1:q)),[],'all'));
out.pass = strcmp(out.simulinkReason,out.matlabReason) && numel(replay.rewards) == n ...
    && out.rewardDiff == 0 && out.observationDiff == 0;
end

function state = policyState(env,observation,arm)
% rolloutEpisodeV2 policy state of the arm's representation.
if strcmp(arm.graphState.stateRepresentation,'baseline')
    state = observation;
else
    state = landing2d.graphstate.environmentGraph(env,arm);
end
end

function [agent,source] = policyFor(arm,folder)
file = fullfile(folder,arm.rl.policyFile);
source = 'initial';
if isfile(file)
    saved = load(file);
    if isfield(saved,'agent') && isfield(saved,'signature') ...
            && landing2d.rl.signatureMatches(saved.signature,arm)
        agent = landing2d.rl.normalizeAgent(saved.agent,arm.rl);
        landing2d.rl.verifyCheckpointGraph(agent,arm);
        source = 'checkpoint';
        return;
    end
end
agent = landing2d.rl.agentInit(arm.rl,RandStream('threefry','Seed',arm.rl.seed+101), ...
    arm.graphState);
end

function text = passText(pass)
if pass, text = 'PASS'; else, text = 'FAIL'; end
end

function options = mergeOptions(options,defaults)
names = fieldnames(options);
unknown = setdiff(names,fieldnames(defaults));
assert(isempty(unknown),'landing2d:UnknownOption', ...
    'Unknown verifyEquivalence option: %s',strjoin(unknown,', '));
for i = 1:numel(names), defaults.(names{i}) = options.(names{i}); end
options = defaults;
end
