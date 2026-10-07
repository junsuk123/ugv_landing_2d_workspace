function [agent,info] = trainAgent(c,trainer)
% TRAINAGENT  PPO로 정책을 학습. 초기 정책은 설정에 따라 두 가지입니다.
%
%   useBehaviorClone = true  : 기준 유도 법칙을 교사로 모방 학습한 정책에서 출발
%   useBehaviorClone = false : 무작위 초기 정책에서 PPO만으로 학습
%
% 교사 없이 학습하면 보상 설계만으로 정책이 만들어지므로, 보상 가중치의
% 기여를 유도 법칙의 기여와 분리해서 볼 수 있습니다. 대신 학습이 훨씬 오래 걸립니다.
%
% trainer(선택)는 PPO 학습 함수입니다. 기본은 MATLAB 판 landing2d.rl.ppoTrain,
% landing2d.rlsim.ppoTrain을 주면 Simulink 모델 + RL Toolbox로 학습합니다.
% 초기화·사전학습·정적 부호기 고정 검사는 두 경우가 같습니다.
if nargin < 2 || isempty(trainer), trainer = @landing2d.rl.ppoTrain; end
rl = c.rl;
if strcmp(func2str(trainer),'landing2d.rl.ppoTrain')
    rl = landing2d.rl.ensurePool(rl);
end
c.rl = rl;
initRs = RandStream('threefry','Seed',rl.seed+101);
pretrainRs = RandStream('threefry','Seed',rl.seed+202);
teacherRs = RandStream('threefry','Seed',rl.seed+303);
ppoRs = RandStream('threefry','Seed',rl.seed+404);
started = tic;
agent = landing2d.rl.agentInit(rl,initRs,c.graphState);
pretrainInfo = struct('enabled',false,'sampleCount',0,'finalLoss',NaN, ...
    'usesActions',false,'usesRewards',false,'usesOutcomes',false, ...
    'usesFuture',false,'seedSplit','train');
if ismember(agent.encoderSpec.mode,{'context_gat','context_rgat'}) ...
        && c.graphState.pretrain.enabled
    [agent.policy.encoder,pretrainInfo] = ...
        landing2d.graphstate.pretrainCausalEncoder( ...
        agent.policy.encoder,agent.encoderSpec,c,pretrainRs);
    % The fixed causal backbone is shared by construction. Heads start from
    % the same pretrained point and adapt independently during PPO.
    agent.value.encoder = agent.policy.encoder;
end
cloneInfo = struct('finalLoss',NaN);
teacherSamples = 0;
if rl.useBehaviorClone
    if rl.verbose
        fprintf('%s 교사 시연 수집 (%d 에피소드)...\n',upper(c.controller),rl.bcEpisodes);
    end
    data = landing2d.rl.teacherDataset(c,rl,teacherRs);
    teacherSamples = data.sampleCount;
    if rl.verbose
        fprintf('모방 학습 (%d 표본, %d 반복)...\n',data.sampleCount,rl.bcEpochs);
    end
    [agent,cloneInfo] = landing2d.rl.behaviorClone(agent,data,teacherRs);
    if rl.verbose
        fprintf('  모방 학습 최종 손실: %.4f\n',cloneInfo.finalLoss);
    end
elseif rl.verbose
    fprintf('모방 학습 없음: 무작위 초기 정책에서 시작합니다.\n');
end
staticReference = staticBackbone(agent.policy.encoder,agent.encoderSpec.mode);
if rl.verbose
    fprintf('PPO 학습 (%d 반복 x %d 에피소드)...\n', ...
        rl.ppoIterations,rl.episodesPerIteration);
end
[agent,history] = trainer(agent,c,ppoRs);
staticFrozen = isequal(staticReference, ...
    staticBackbone(agent.policy.encoder,agent.encoderSpec.mode));
if c.graphState.freezeStaticBackbone
    assert(staticFrozen,'landing2d:StaticBackboneChanged', ...
        'A frozen causal graph backbone changed during PPO.');
end
info = struct('teacherSamples',teacherSamples, ...
    'useBehaviorClone',rl.useBehaviorClone, ...
    'cloneLoss',cloneInfo.finalLoss,'history',history, ...
    'pretraining',pretrainInfo,'staticBackboneFrozen',staticFrozen, ...
    'trainingSeconds',toc(started),'trainer',func2str(trainer));
if rl.verbose
    fprintf('학습 시간: %.1f s\n',info.trainingSeconds);
end

function value=staticBackbone(encoder,mode)
value=struct();
if ~ismember(mode,{'context_gat','context_rgat'}), return; end
for name={'E1','W0','b0'}
    value.(name{1})=encoder.(name{1});
end
end
end
