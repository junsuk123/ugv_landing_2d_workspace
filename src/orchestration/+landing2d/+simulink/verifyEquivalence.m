function report = verifyEquivalence(options)
% VERIFYEQUIVALENCE  Simulink 환경·정책이 MATLAB 계약과 같은지 확인.
%
%   report = landing2d.simulink.verifyEquivalence()
%   report = landing2d.simulink.verifyEquivalence(struct('modes',{{'context_rgat'}}, ...
%       'seedCount',3))
%
% 비교군과 검증 seed마다 두 가지를 봅니다.
%   replay      MATLAB rolloutEpisodeV2(결정론)의 명령 u를 Action player 모델에서
%               재생합니다. 동역학·패드·카메라 잡음·추적기·감독기·종료·보상·관측이
%               비트 단위로 같아야 합니다 (차이 0).
%   closedLoop  같은 정책을 rlPPOAgent로 바꿔 RL Agent 블록이 운전합니다.
%               RL Toolbox 망은 single로 계산하므로 종료 사유와 결정 수가 같고
%               보상 차이가 closedLoopTolerance 이하이면 통과입니다.
% 학습된 체크포인트가 있으면 그 정책을, 없으면 같은 seed의 초기 정책을 씁니다.
if nargin < 1, options = struct(); end
projectRoot = landing2d.orchestration.projectRoot();
cfg = landing2d.config.primaryConfig(projectRoot);
defaults = struct('modes',{{'baseline','context_flat','context_rgat'}}, ...
    'seedCount',2,'checkpointDir',cfg.outputDir, ...
    'closedLoopTolerance',1e-3,'verbose',true);
options = mergeOptions(options,defaults);
cfg.outputDir = fullfile(tempdir,'landing2d_simulink_verify');
rows = {};
for m = 1:numel(options.modes)
    mode = options.modes{m};
    arm = landing2d.graphstate.applyStateRepresentation(cfg,mode);
    arm.rl.verbose = false;
    [agent,source] = policyFor(arm,mode,options.checkpointDir);
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
        rows(end+1,:) = {string(mode),string(source),seeds(i), ...
            string(result.terminalReason),traj.count,string(replay.reason), ...
            numel(replay.rewards),rewardDiff,observationDiff,replayPass, ...
            string(loop.reason),numel(loop.rewards),loopDiff,loopPass}; %#ok<AGROW>
        if options.verbose
            fprintf(['%-13s seed %d  MATLAB %-22s %4d | replay diff %.3g/%.3g %s' ...
                ' | closed loop %-22s diff %.3g %s\n'],mode,seeds(i), ...
                result.terminalReason,traj.count,rewardDiff,observationDiff, ...
                passText(replayPass),loop.reason,loopDiff,passText(loopPass));
        end
    end
    close_system(player,0);
    close_system(closed,0);
end
report = cell2table(rows,'VariableNames',{'StateRepresentation','Policy', ...
    'Seed','MatlabReason','MatlabDecisions','ReplayReason','ReplayDecisions', ...
    'ReplayMaxRewardDiff','ReplayMaxObservationDiff','ReplayPass', ...
    'ClosedLoopReason','ClosedLoopDecisions','ClosedLoopMaxRewardDiff', ...
    'ClosedLoopPass'});
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

function [agent,source] = policyFor(arm,mode,folder)
file = fullfile(folder,sprintf('ppo_%s_planar_visibility_v2.mat',mode));
source = 'initial';
if isfile(file)
    saved = load(file);
    if isfield(saved,'agent')
        agent = landing2d.rl.normalizeAgent(saved.agent,arm.rl);
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
