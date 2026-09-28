function [advantage,target] = computeAdvantage(traj,rl)
% COMPUTEADVANTAGE  GAE(lambda). 마지막 상태 가치는 traj.bootstrap 사용.
% 착륙/실패로 끝난 경우 bootstrap은 0입니다. 남은 유한 지평선의 흡수상태
% 보상은 rolloutEpisode가 마지막 보상에 이미 합산합니다.
count = traj.count;
advantage = zeros(1,count);
running = 0;
for k = count:-1:1
    if k == count
        nextValue = traj.bootstrap;
    else
        nextValue = traj.value(k+1);
    end
    delta = traj.reward(k)+rl.gamma*nextValue-traj.value(k);
    running = delta+rl.gamma*rl.lambda*running;
    advantage(k) = running;
end
target = advantage+traj.value;
end
