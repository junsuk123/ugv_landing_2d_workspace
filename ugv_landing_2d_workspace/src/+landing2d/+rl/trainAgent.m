function [agent,info] = trainAgent(c)
% TRAINAGENT  PPO로 정책을 학습. 초기 정책은 설정에 따라 두 가지입니다.
%
%   useBehaviorClone = true  : 기준 유도 법칙을 교사로 모방 학습한 정책에서 출발
%   useBehaviorClone = false : 무작위 초기 정책에서 PPO만으로 학습
%
% 교사 없이 학습하면 보상 설계만으로 정책이 만들어지므로, 보상 가중치의
% 기여를 유도 법칙의 기여와 분리해서 볼 수 있습니다. 대신 학습이 훨씬 오래 걸립니다.
rl = c.rl;
rl = landing2d.rl.ensurePool(rl);
c.rl = rl;
rs = RandStream('threefry','Seed',rl.seed);
started = tic;
agent = landing2d.rl.agentInit(rl,rs,c.graphState);
cloneInfo = struct('finalLoss',NaN);
teacherSamples = 0;
if rl.useBehaviorClone
    if rl.verbose
        fprintf('%s 교사 시연 수집 (%d 에피소드)...\n',upper(c.controller),rl.bcEpisodes);
    end
    data = landing2d.rl.teacherDataset(c,rl,rs);
    teacherSamples = data.sampleCount;
    if rl.verbose
        fprintf('모방 학습 (%d 표본, %d 반복)...\n',data.sampleCount,rl.bcEpochs);
    end
    [agent,cloneInfo] = landing2d.rl.behaviorClone(agent,data,rs);
    if rl.verbose
        fprintf('  모방 학습 최종 손실: %.4f\n',cloneInfo.finalLoss);
    end
elseif rl.verbose
    fprintf('모방 학습 없음: 무작위 초기 정책에서 시작합니다.\n');
end
if rl.verbose
    fprintf('PPO 학습 (%d 반복 x %d 에피소드)...\n', ...
        rl.ppoIterations,rl.episodesPerIteration);
end
[agent,history] = landing2d.rl.ppoTrain(agent,c,rs);
info = struct('teacherSamples',teacherSamples, ...
    'useBehaviorClone',rl.useBehaviorClone, ...
    'cloneLoss',cloneInfo.finalLoss,'history',history, ...
    'trainingSeconds',toc(started));
if rl.verbose
    fprintf('학습 시간: %.1f s\n',info.trainingSeconds);
end
end
