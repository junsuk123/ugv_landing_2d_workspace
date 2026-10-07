function output = runScenario(scenarioId,options)
% RUNSCENARIO  대표 시나리오(S1–S3)를 Simulink 모델에서 최종 정책으로 실행.
%
%   out = landing2d.simulink.runScenario('S3')
%   out = landing2d.simulink.runScenario('S3',struct('modes',{{'context_rgat'}}, ...
%       'open',true))
%
% landing2d.orchestration.validateStudy와 같은 고정 시나리오·센서 사건·seed로
% 비교군마다 RL Agent 블록 모델을 결정론 정책으로 돌립니다. open이 참이면
% 모델과 Scope(드론·UGV·카메라·return)를 열어 시뮬레이션 중 신호를 보여 줍니다.
% 체크포인트는 checkpointDir(기본: results/simulink가 있으면 그곳, 없으면 results)
% 에서 읽고, 학습하지 않습니다.
if nargin < 1 || isempty(scenarioId), scenarioId = 'S1'; end
if nargin < 2, options = struct(); end
projectRoot = landing2d.orchestration.projectRoot();
cfg = landing2d.config.primaryConfig(projectRoot);
simulinkDir = fullfile(cfg.outputDir,'simulink');
defaultDir = cfg.outputDir;
if isfolder(simulinkDir) && ~isempty(dir(fullfile(simulinkDir,'ppo_*_planar_visibility_v2.mat')))
    defaultDir = simulinkDir;
end
defaults = struct('modes',{{'baseline','context_flat','context_rgat'}}, ...
    'checkpointDir',defaultDir,'open',false,'verbose',true);
options = mergeOptions(options,defaults);
scenarioId = upper(char(scenarioId));
specs = landing2d.paper.representativeScenarios(cfg);
index = find(strcmp({specs.id},scenarioId),1);
assert(~isempty(index),'landing2d:ScenarioId','scenarioId must be S1, S2, or S3.');
spec = specs(index);
cfg.outputDir = char(options.checkpointDir);
runs = struct('mode',{},'model',{},'terminalReason',{},'decisions',{}, ...
    'episodeReturn',{},'log',{});
for m = 1:numel(options.modes)
    mode = options.modes{m};
    arm = landing2d.graphstate.applyStateRepresentation(cfg,mode);
    arm.rl.policyFile = sprintf('ppo_%s_planar_visibility_v2.mat',mode);
    arm.rl.verbose = false;
    agent = landing2d.rl.loadCheckpoint(arm);
    toolbox = landing2d.rlsim.toolboxAgent(agent,arm,'raw');
    toolbox.UseExplorationPolicy = false;
    assignin('base','landing2dAgent',toolbox);
    model = landing2d.simulink.buildModel(arm);
    resetOptions = struct('scenario',spec.scenario,'sensorEvents',spec.sensorEvents);
    landing2d.simulink.episodeServer('setSource', ...
        landing2d.simulink.SeedListSource(arm,spec.seed,{},{resetOptions}));
    landing2d.simulink.episodeServer('advance');
    if options.open
        open_system(model);
        scopes = find_system(model,'LookUnderMasks','all','BlockType','Scope');
        for k = 1:numel(scopes), open_system(scopes{k}); end
    end
    sim(model);
    episode = landing2d.simulink.episodeServer('current');
    entries = [episode.log{:}];
    reason = '';
    if ~isempty(episode.outcome), reason = episode.outcome.terminalReason; end
    runs(end+1) = struct('mode',mode,'model',model,'terminalReason',reason, ...
        'decisions',numel(entries)-1,'episodeReturn',sum([entries.reward]), ...
        'log',entries); %#ok<AGROW>
    if options.verbose
        fprintf('  %s %-13s %-22s %4d decisions  return %8.3f  (Simulink %s)\n', ...
            spec.id,mode,reason,numel(entries)-1,sum([entries.reward]),model);
    end
end
landing2d.simulink.episodeServer('clear');
output = struct('scenario',spec,'runs',runs,'checkpointDir',options.checkpointDir);
end

function options = mergeOptions(options,defaults)
assert(isstruct(options) && isscalar(options),'landing2d:InvalidOptions', ...
    'options must be a scalar struct.');
names = fieldnames(options);
unknown = setdiff(names,fieldnames(defaults));
assert(isempty(unknown),'landing2d:UnknownOption', ...
    'Unknown Simulink scenario option: %s',strjoin(unknown,', '));
for i = 1:numel(names), defaults.(names{i}) = options.(names{i}); end
options = defaults;
options.modes = cellstr(options.modes);
end
