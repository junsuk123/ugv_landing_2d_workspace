function [agent,info] = behaviorClone(agent,data,rs)
% BEHAVIORCLONE  교사 시연으로 정책 평균망을 지도학습. PPO의 초기 정책이 됩니다.
rl = agent.rl;
n = data.sampleCount;
state = landing2d.util.adamInit(agent.policy.mean);
encoderState = landing2d.util.adamInit(agent.policy.encoder);
hasEncoder = ~isempty(fieldnames(agent.policy.encoder));
info.loss = nan(rl.bcEpochs,1);
for epoch = 1:rl.bcEpochs
    order = randperm(rs,n);
    total = 0;
    batches = 0;
    for start = 1:rl.bcBatch:n
        index = order(start:min(start+rl.bcBatch-1,n));
        X = data.state(:,index);
        Y = data.command(:,index);
        [g,encoderCache] = landing2d.graphstate.encoderForward( ...
            agent.policy.encoder,agent.encoderSpec,X);
        [prediction,cache] = landing2d.rl.mlpForward(agent.policy.mean,g);
        residual = prediction-Y;
        total = total+mean(sum(residual.^2,1));
        batches = batches+1;
        [grads,dG] = landing2d.rl.mlpBackward(agent.policy.mean,cache, ...
            2*residual/numel(index));
        [agent.policy.mean,state] = landing2d.util.adamUpdate( ...
            agent.policy.mean,grads,state,rl.bcLearnRate);
        if hasEncoder
            % 그래프 부호기도 함께 학습합니다. 부호기를 얼려 두면 정책이
            % 무작위 사영 위에서만 맞춰져 모방 학습의 의미가 사라집니다.
            encoderGrads = landing2d.graphstate.encoderBackward( ...
                agent.policy.encoder,agent.encoderSpec,encoderCache,dG);
            [agent.policy.encoder,encoderState] = landing2d.util.adamUpdate( ...
                agent.policy.encoder,encoderGrads,encoderState,rl.bcLearnRate);
        end
    end
    info.loss(epoch) = total/batches;
end
info.finalLoss = info.loss(end);
end
