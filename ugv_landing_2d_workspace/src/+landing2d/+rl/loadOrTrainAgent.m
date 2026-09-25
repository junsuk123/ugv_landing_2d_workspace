function [agent,info] = loadOrTrainAgent(c)
% LOADORTRAINAGENT  저장된 정책이 현재 설정과 같으면 재사용, 아니면 학습 후 저장.
file = fullfile(c.outputDir,c.rl.policyFile);
signature = landing2d.rl.trainingSignature(c);
if ~c.rl.retrain && isfile(file)
    saved = load(file);
    if isfield(saved,'agent') && isfield(saved,'signature') ...
            && isequal(saved.signature,signature)
        agent = landing2d.rl.normalizeAgent(saved.agent,c.rl);
        info = saved.info;
        if c.rl.verbose
            fprintf('저장된 정책을 사용합니다: %s\n',file);
        end
        publishSavedHistory(c,info);
        return;
    end
end
[agent,info] = landing2d.rl.trainAgent(c);
if ~exist(c.outputDir,'dir')
    [ok,message] = mkdir(c.outputDir);
    if ~ok, error('landing2d:OutputDirectory','%s',message); end
end
save(file,'agent','info','signature');
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
    payload = struct('label',label,'iteration',h.iteration, ...
        'maxIteration',c.rl.ppoIterations,'score',h.score, ...
        'trainReturn',h.trainReturn,'landingRate',h.landingRate, ...
        'captureRate',h.captureRate);
    landing2d.viz.liveDashboard('training',payload);
end
end
