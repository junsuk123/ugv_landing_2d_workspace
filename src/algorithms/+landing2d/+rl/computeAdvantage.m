function [advantage,valueTarget] = computeAdvantage(traj,rl)
% COMPUTEADVANTAGE  GAE(lambda). 마지막 상태 가치는 traj.bootstrap 사용.
% 착륙/실패로 끝난 경우 bootstrap은 0입니다. 남은 유한 지평선의 흡수상태
% 보상은 rolloutEpisode가 마지막 보상에 이미 합산합니다.
% valueTarget = advantage + V(s): Critic 학습 목표(GAE 가치 목표)입니다.
count = traj.count;
advantage = zeros(1,count);
runningAdvantage = 0;
for k = count:-1:1
    if isfield(traj,'discount') && numel(traj.discount)>=k
        discount = traj.discount(k);
    else
        discount = rl.gamma;
    end
    if isfield(traj,'terminated') && traj.terminated(k)
        nextValue = 0;
        continuation = 0;
    elseif k == count
        nextValue = traj.bootstrap;
        continuation = 1;
    else
        nextValue = traj.value(k+1);
        continuation = 1;
    end
    delta = traj.reward(k)+discount*nextValue-traj.value(k);
    runningAdvantage = delta+discount*rl.lambda*continuation*runningAdvantage;
    advantage(k) = runningAdvantage;
end
valueTarget = advantage+traj.value;
end
