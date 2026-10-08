function [agent,info,file] = loadOrTrainAgent(c,trainer)
% LOADORTRAINAGENT  저장된 정책이 현재 설정과 같으면 재사용, 아니면 학습 후 저장.
% trainer(선택): PPO 학습 함수. 기본 landing2d.rl.ppoTrain, Simulink 학습은
% landing2d.rlsim.ppoTrain. 관계 경로 활성화도 같은 학습 함수를 씁니다.
% 체크포인트에는 agent(실제 사용한 그래프 src/dst/type_id·graph_hash 포함),
% info, signature와 실행 식별 정보 run(method_id·시드·그래프)을 저장합니다.
if nargin < 2 || isempty(trainer), trainer = @landing2d.rl.ppoTrain; end
file = fullfile(c.outputDir,c.rl.policyFile);
signature = landing2d.rl.trainingSignature(c);
if ~c.rl.retrain && isfile(file)
    saved = load(file);
    if isfield(saved,'agent') && isfield(saved,'signature') ...
            && landing2d.rl.signatureMatches(saved.signature,c)
        agent = landing2d.rl.normalizeAgent(saved.agent,c.rl);
        landing2d.rl.verifyCheckpointGraph(agent,c);
        info = saved.info;
        if c.rl.verbose
            fprintf('저장된 정책을 사용합니다: %s\n',file);
        end
        publishSavedHistory(c,info);
        return;
    end
end
[agent,info] = landing2d.rl.trainAgent(c,trainer);
info.relationActivation = struct('required',false,'attempted',false, ...
    'changed',false,'accepted',true,'seconds',0, ...
    'reason','direct_graph_embedding');
folder = fileparts(file);
if ~exist(folder,'dir')
    [ok,message] = mkdir(folder);
    if ~ok, error('landing2d:OutputDirectory','%s',message); end
end
run = landing2d.rl.runIdentity(agent,c); %#ok<NASGU>
save(file,'agent','info','signature','run');
if c.rl.verbose
    fprintf('학습한 정책 저장: %s\n',file);
end
end

function publishSavedHistory(c,info)
if ~isfield(c,'showLiveDashboard') || ~c.showLiveDashboard ...
        || ~isfield(c,'figureVisible') || ~c.figureVisible ...
        || ~isfield(info,'history') || isempty(info.history)
    return;
end
label = c.graphState.stateRepresentation;
if isfield(c,'dashboardAgentLabel') && ~isempty(c.dashboardAgentLabel)
    label = c.dashboardAgentLabel;
end
for i = 1:numel(info.history)
    h = info.history(i);
    selectionScore = NaN;
    if isfield(h,'selectionScore'), selectionScore = h.selectionScore; end
    payload = struct('label',label,'iteration',h.iteration, ...
        'maxIteration',c.rl.ppoIterations,'score',h.score, ...
        'selectionScore',selectionScore, ...
        'trainReturn',h.trainReturn,'landingRate',h.landingRate, ...
        'captureRate',h.captureRate);
    optional = {'trainLandingRate','trainNominalLandingRate', ...
        'trainCurriculumLandingRate','trainSafeAbortRate','curriculumLevel'};
    for k = 1:numel(optional)
        name = optional{k};
        if isfield(h,name), payload.(name) = h.(name); end
    end
    diagnostics = {'nodeMean','nodeVariance','edgeAttentionMean','graphSchema'};
    for k = 1:numel(diagnostics)
        name = diagnostics{k};
        if isfield(h,name), payload.(name) = h.(name); end
    end
    landing2d.viz.liveDashboard('training',payload);
end
end
