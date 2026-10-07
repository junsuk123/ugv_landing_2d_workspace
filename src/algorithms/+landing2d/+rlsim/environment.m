function [env,model,workers] = environment(c)
% ENVIRONMENT  비교군 설정 c의 Simulink 모델을 만들고 rlSimulinkEnv로 감쌉니다.
%
% rl.parallelEpisodes가 참이면 landing2d.rl.ensurePool로 병렬 풀을 준비하고,
% 워커가 landing2d 소스와 생성된 모델을 찾도록 경로를 추가합니다.
% ResetFcn은 학습 구간마다 landing2d.rlsim.ppoTrain이 지정합니다.
[model,file] = landing2d.simulink.buildModel(c,struct('actionSource','agent'));
if c.rl.verbose && ~isempty(file)
    fprintf('Simulink model: %s\n',file);
end
folder = fileparts(file);
if ~isempty(folder) && ~contains([path pathsep],[folder pathsep])
    addpath(folder);
end
workers = 1;
rl = landing2d.rl.ensurePool(c.rl);
if rl.parallelEpisodes
    pool = gcp('nocreate');
    if ~isempty(pool) && pool.NumWorkers > 1
        workers = pool.NumWorkers;
        roots = sourceRoots();
        if ~isempty(folder), roots{end+1} = folder; end
        wait(parfevalOnAll(pool,@addpath,0,roots{:}));
    end
end
[obsInfo,actInfo] = landing2d.rlsim.specs(c,policyStateDim(c));
env = rlSimulinkEnv(model,[model '/RL Agent'],obsInfo,actInfo);
env.UseFastRestart = 'on';
end

function roots = sourceRoots()
root = landing2d.orchestration.projectRoot();
roots = {fullfile(root,'src','orchestration'),fullfile(root,'src','simulations'), ...
    fullfile(root,'src','algorithms')};
end

function n = policyStateDim(c)
if strcmp(c.graphState.stateRepresentation,'baseline')
    n = c.experiment.observationSchema.dimension;
else
    schema = landing2d.graphstate.contextSchema(c.graphState.stateRepresentation);
    n = schema.inDim*schema.nNodes;
end
end
