function [ax,az] = actionFromCommand(u,c)
% ACTIONFROMCOMMAND  제한 없는 정책 출력을 가속도 한계 안으로 사상.
% 포화가 정책 분포 밖(환경 쪽)에 있으므로 log 확률 보정이 필요 없습니다.
ax = c.axMax*tanh(u(1));
az = c.azMax*tanh(u(2));
end
